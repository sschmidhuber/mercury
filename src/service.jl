"""
    healthcheck()

Return metrics about system health.
"""
function healthcheck()
    hostinfo = retrieve_host_info("localhost")
    memory = map(meminfo(hostinfo)) do value
        round(value / 1024 / 1024, digits=2)
    end

    return memory
end


"""
    add_dataset(id::UUID, filename::Vector{AbstractString}, type::Vector{MIME}, files)

Add a new Data Set
"""
function add_dataset(id::UUID, label::String, retention_time::Int, hidden::Bool, public::Bool, files::Vector{File})
    ds = DataSet(id, strip(label), [], retention_time, hidden, public, files)
    create_dataset(ds)
    return ds
end


"""
    process_dataset(id::UUID)

Process a newly uploaded dataset.
"""
function process_dataset(id::UUID)
    if config["skip_malware_check"] && prepare(id)
        promote_dataset(id)
    elseif malwarescan(id) && prepare(id)
        promote_dataset(id)
    else
        @warn "processing DataSet: $(string(id)) failed"
    end
end


"""
    malwarescan(id::UUID)::Bool

Returns true, if scan was successful (no malware found) or false if test failed or malware was detected.
In case malware was found, the data will be deleted immediately.
"""
function malwarescan(id::UUID)::Bool
    try
        ds = read_dataset(id)
        if isnothing(ds)
            @warn "no files found corresponding to ID: $id"
            return false
        end
        
        dir = joinpath(config["storage_dir"], "tmp", string(id))
        try
            run(`clamscan -ri --no-summary $dir`)
            ds.stage = scanned
            ds.stagechange = now()
            update_dataset(ds)
            return true
        catch e
            @warn "malware check failed for: $id"
            if e isa Base.IOError
                @warn "check if clamav is installed on the host"
            end
            delete_dataset(id, hard = true)
            return false
        end          
    catch _
        @warn "malware check failed"
        return false
    end        
end



"""
    prepare(id::UUID)

Preprocess DataSet and set stage to "prepared" before it can be promoted for download.
Return true if preparation was executed successfully, othewise return false.
"""
function prepare(id::UUID)::Bool
    try
        ds = read_dataset(id)
        if isnothing(ds)
            @warn "no DataSet found corresponding to ID: $id"
            return false
        else
            #TODO: add DataSet validation, create icons/thumbnails, QR code,...
            ds.stage = prepared
            ds.stagechange = now()
            update_dataset(ds)
            return true
        end
    catch _
        @warn "preparation step of: $(string(id)) failed"
        return false
    end        
end


"""
    properties(id::UUID)

Return properties of the data set associated to the given ID.
"""
function properties(id::UUID)
    ds = read_dataset(id)
    if isnothing(ds)
        return nothing
    else
        return dataset_to_dict(ds)
    end    
end


"""
    count_ds()

Return the number of available data sets.
"""
function count_ds()
    ds = read_datasets()
    filter(x -> x.stage == available, ds) |> length
end


"""
    available_storage()

Return available storage in bytes.
"""
function available_storage()
    ds = read_datasets()
    used_storage = map(d -> storage_size(d), ds) |> sum
    min(diskstat(config["storage_dir"]).available, config["limits"]["storage"] - used_storage)
end


"""
    status()

Return system status.
"""
function status(internal)
    ds = read_datasets()
    local count_ds, count_files
    if internal
        count_ds = filter(x -> x.stage == available, ds) |> length
        count_files = @chain ds begin
            filter(x -> x.stage == available, _)
            map(x -> length(x.files), _)
            sum
        end
    else
        count_ds = filter(x -> x.stage == available && x.public, ds) |> length
        count_files = @chain ds begin
            filter(x -> x.stage == available && x.public, _)
            map(x -> length(x.files), _)
            sum
        end        
    end


    dict = Dict{String, Any}(
        "count_datasets" => count_ds,
        "count_files" => count_files
    )

    if internal
        used_storage = map(d -> sum(map(f -> f.size, d.files)), ds) |> sum
        available_storage = min(diskstat(config["storage_dir"]).available, config["limits"]["storage"] - used_storage) |> Int
        total_storage = available_storage + used_storage
        used_relative = used_storage / total_storage * 100 |> round |> Int

        dict["used_storage"] = format_size(used_storage)
        dict["available_storage"] = format_size(available_storage)
        dict["total_storage"] = format_size(total_storage)
        dict["used_relative"] = "$used_relative %"
    end

    return dict
end


"""
    add_chunk(dsid::UUID, fid::Int, chunk::Int, blob::AbstractArray)::Nothing

Add a new chunk of a file to a DataSet. Throws a DomainError if any input validation fails.
Returns the upload progress of the DataSet and the currently uploaded file.
"""
function add_chunk(dsid::UUID, fid::Int, chunk::Int, blob::AbstractArray)::NamedTuple
    ds = read_dataset(dsid)
    
    # validations
    if isnothing(ds)
        @warn "Dataset: $dsid not found, can't add new chunk"
        throw(DomainError(dsid, "no DataSet with given ID found"))
    end
    if ds.files |> length < fid
        @warn "File: $fid of DataSet $dsid not found, can't add new chunk"
        throw(DomainError(fid, "no File with given ID found"))
    end
    if ds.files[fid].chunks_received + 1 != chunk || ds.files[fid].chunks_total < chunk
        @warn "Unexpected chunk: $chunk of file $fid of DataSet $dsid, can't add new chunk"
        throw(DomainError(fid, "unexpected chunk"))
    end
    expected_chunk_size = if ds.files[fid].chunks_total > chunk
        config["network"]["chunk_size"]
    else
        # last or only chunk
        ds.files[fid].size - (chunk - 1) * config["network"]["chunk_size"]
    end
    if length(blob) != expected_chunk_size
        @warn "Unexpected chunk size: $(length(blob)) (expected: $expected_chunk_size) of file $fid of DataSet $dsid, can't add new chunk"
        throw(DomainError(length(blob), "unexpected chunk size"))
    end

    try
        store_chunk(ds, fid, chunk, blob)
    catch err
        rethrow(err)
    end

    ds.files[fid].chunks_received += 1
    if ds.files[fid].chunks_total == ds.files[fid].chunks_received
        ds.files[fid].timestamp_uploaded = now()        
    end
    update_dataset(ds)
    progress = upload_progress(ds, fid)
    
    if progress.completed
        @debug "upload completed, trigger further processing"
        Threads.@spawn process_dataset(ds.id)
    end

    return progress
end


function upload_progress(ds, fid)
    ds_chunks_total = map(file -> file.chunks_total, ds.files) |> sum
    ds_chunks_received = map(file -> file.chunks_received, ds.files) |> sum
    f_chunks_total = ds.files[fid].chunks_total
    f_chunks_received = ds.files[fid].chunks_received

    return (progress_dataset=Int(round(ds_chunks_received/ds_chunks_total * 100, digits=0)), file=joinpath(ds.files[fid].directory, ds.files[fid].name), progress_file=Int(round(f_chunks_received/f_chunks_total * 100, digits=0)), completed=ds_chunks_received==ds_chunks_total)
end

"""
    clientconfig(internal=false)

Returns configuration for the web client.
"""
function clientconfig(internal=false)
    Dict(
        "internal" => internal,
        "retention_default" => config["retention"]["default"],
        "retention_min" => config["retention"]["min"],
        "retention_max" => config["retention"]["max"] == Inf ? "Infinity" : config["retention"]["max"],
        "chunk_size" => config["network"]["chunk_size"],
        "filesize" => config["limits"]["filesize"],
        "filesize_f" => config["limits"]["filesize"] |> format_size,
        "filenumber_per_dataset" => config["limits"]["filenumber_per_dataset"],
        "datasetsize" => config["limits"]["datasetsize"],
        "datasetsize_f" => config["limits"]["datasetsize"] |> format_size,
        "datasetnumber" => config["limits"]["datasetnumber"]
    )
end


"""
    available_datasets(internal=false)

Return status of available datasets. If private is set to true private and public data sets will be returned.
If private=false (default) only public datasets will be returned.
"""
function available_datasets(internal=false)
    ds = @chain read_datasets() begin
        map(d -> read_dataset(d.id), _)
        filter(d -> d.stage == available, _)
        filter(d -> d.hidden == false, _)
        sort(_, by = x -> lowercase(x.label))
    end

    if !internal
        filter!(d -> d.public, ds)
    end

    if isempty(ds)
        return []
    else
        return dataset_to_dict.(ds)
    end
end


"""
    download_path(id::UUID)

Return the path of the correspoonding download artefact associated to the given ID.
Return nothing, if there is no data set corresponding to the given ID.
"""
function get_download_uri(id::UUID)
    ds = read_dataset(id)
    if isnothing(ds) || ds.stage != available
        return nothing
    end

    directory  = "/live/" * string(id) * "/"
    filename = length(ds.files) == 1 && ds.files[1].directory |> isempty ? ds.files[1].name : ds.label * ".zip"

    return directory * filename
end


function increment_download_counter(id::UUID)
    ds = read_dataset(id)
    if isnothing(ds) || ds.stage != available
        return nothing
    end

    ds.downloads += 1
    update_dataset(ds)
end


"""
    cleanup()

Periodically delete datasets if retention time is exceeded.
"""
function cleanup()
    while true
        ts = now()
        ds = read_datasets()

        foreach(ds) do d
            if d.stage == available
                if d.timestamp + Hour(d.retention) < ts
                    @info "delete $(d.label), ID: $(d.id)"
                    delete_dataset(d.id)
                end
            elseif d.stage == deleted
                if d.stagechange + Hour(config["retention"]["purge"]) < ts
                    @info "permanently delete $(d.label), ID: $(d.id)"
                    delete_dataset(d.id, hard=true, dbrecord=true)
                end
            elseif d.stage == initial || d.stage == scanned
                if d.timestamp + Day(1) < ts
                    @info "remove from tmp layer: $(d.label), ID: $(d.id)"
                    delete_dataset(d.id, hard=true)
                end
            end
        end
        sleep(config["retention"]["interval"])
    end
end