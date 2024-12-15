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
    add_dataset(id::UUID, label::String, retention_time::Int, hidden::Bool, public::Bool, files::Vector{File})::DataSet

Add a new Data Set
"""
function add_dataset(id::UUID, label::String, retention_time::Int, hidden::Bool, public::Bool, files::Vector{File})::DataSet
    @debug "add dataset"
    ds = DataSet(id, strip(label), [], retention_time, hidden, public, files)
    create_dataset(ds)
    return ds
end


"""
    process_dataset(id::UUID)

Process a newly uploaded dataset.
"""
function process_dataset(id::UUID)
    @debug "process a dataset"
    if config["skip_malware_check"] && prepare(id)
        update_dataset_promote(id)
    elseif malwarescan(id) && prepare(id)
        update_dataset_promote(id)
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
            update_dataset_stage(id, scanned)
            return true
        catch e
            @warn "malware check failed for: $id"
            if e isa Base.IOError
                @warn "check if clamav is installed on the host"
            end
            delete_dataset_hard(id)
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
    @debug "prepare a dataset"
    try
        ds = read_dataset(id)
        if isnothing(ds)
            @warn "no DataSet found corresponding to ID: $id"
            return false
        else
            #TODO: add DataSet validation, create icons/thumbnails, QR code,...
            update_dataset_stage(id, prepared)
            return true
        end
    catch _
        @warn "preparation step of: $(string(id)) failed"
        return false
    end        
end


"""
    nextchunk(ds::DataSet)::Union{Tuple,Nothing}

Returns a tuple of file ID and chunk which is expected to be uploaded by the client next
or nothing if there are no missing data chunks in the given data set.
"""
function nextchunk(ds::DataSet, fid, chunk)::Tuple
    if ds.files[fid].chunks_total > chunk
        return fid, chunk + 1
    elseif length(ds.files) > fid
        return fid + 1, 1
    else
        return nothing, nothing
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
    storage_status(internal)::StorageStatus

Return mercury's storeage status, in terms of stored datasets and available storage.
"""
function storage_status(internal)::StorageStatus
    df = read_dataset_metrics()

    if internal
        if nrow(df) == 0
            count_ds, count_files, used_storage = 0, 0, 0
        else
            count_ds = df[df.stage .== available,:datasets] |> sum
            count_files = df[df.stage .== available,:files] |> sum
            used_storage = df[df.stage .== available,:used_storage] |> sum
        end        
        available_storage = min(diskstat(config["storage_dir"]).available, config["limits"]["storage"] - used_storage) |> Int
        total_storage = available_storage + used_storage
        used_relative = used_storage / total_storage * 100 |> round |> Int

        status = StorageStatus(count_ds, count_files, format_size(used_storage), format_size(available_storage), format_size(total_storage), "$used_relative %")
    else
        count_ds = df[df.stage .== available .&& df.public .== true,:datasets] |> sum
        count_files = df[df.stage .== available .&& df.public .== true,:files] |> sum
        status = StorageStatus(count_ds, count_files)
    end

    return status
end


"""
    add_chunk(ds::DataSet, fid::Int, chunk::Int, blob::AbstractArray)::NamedTuple

Add a new chunk of a file to a DataSet. Throws a DomainError if any input validation fails.
Returns the upload progress of the DataSet and the currently uploaded file.
"""
function add_chunk(ds::DataSet, fid::Int, chunk::Int, blob::AbstractArray)::UploadProgress
    # validations
    if isnothing(ds)
        @warn "Dataset: $(ds.id) not found, can't add new chunk"
        throw(DomainError(ds.id, "no DataSet with given ID found"))
    end
    if length(ds.files) < fid
        @warn "File: $fid of DataSet $(ds.id) not found, can't add new chunk"
        throw(DomainError(fid, "no File with given ID found"))
    end
    if ds.files[fid].chunks_received + 1 != chunk || ds.files[fid].chunks_total < chunk
        @warn "Unexpected chunk: $chunk of file $fid of DataSet $(ds.id), can't add new chunk"
        throw(DomainError(fid, "unexpected chunk"))
    end
    expected_chunk_size = if ds.files[fid].chunks_total > chunk
        config["network"]["chunk_size"]
    else
        # last or only chunk
        ds.files[fid].size - (chunk - 1) * config["network"]["chunk_size"]
    end
    if length(blob) != expected_chunk_size
        @warn "Unexpected chunk size: $(length(blob)) (expected: $expected_chunk_size) of file $fid of DataSet $(ds.id), can't add new chunk"
        throw(DomainError(length(blob), "unexpected chunk size"))
    end

    try
        create_file_chunk(ds, fid, chunk, blob)
    catch err
        showerror(stderr, err)
        rethrow(err)
    end

    if ds.files[fid].chunks_total == chunk
        update_file_chunks_received(ds, fid, chunk, now())
    else
        update_file_chunks_received(ds, fid, chunk)
    end
    ds.files[fid].chunks_received = chunk
    progress = upload_progress(ds, fid, chunk)
    
    if progress.ds_completed
        @debug "upload completed, trigger further processing"
        Threads.@spawn process_dataset(ds.id)
    end

    return progress
end


function upload_progress(ds, fid, chunk)::UploadProgress
    ds_chunks_total = map(file -> file.chunks_total, ds.files) |> sum
    ds_chunks_received = map(file -> file.chunks_received, ds.files) |> sum
    f_chunks_total = ds.files[fid].chunks_total
    f_chunks_received = chunk
    next_file_id, next_chunk_id = nextchunk(ds, fid, chunk)

    return UploadProgress(
        Int(round(ds_chunks_received/ds_chunks_total * 100, digits=0)),
        ds_chunks_received==ds_chunks_total,
        Int(round(f_chunks_received/f_chunks_total * 100, digits=0)),
        joinpath(ds.files[fid].directory, ds.files[fid].name),
        fid,
        f_chunks_total==f_chunks_received,
        next_file_id,
        next_chunk_id
    )
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
    available_datasets(internal=false)::Union{Vector{DataSet},Nothing}

Return a Vector of all available datasets or nothing if no datasets are available.
If internal is set to true private and public data sets will be returned.
If internal=false (default) only public datasets will be returned.
"""
function available_datasets(internal=false)::Union{Vector{DataSet},Nothing}
    datasets = read_datasets(stages=[available], hidden=false, public=(internal ? nothing : true))
    return isempty(datasets) ? nothing : datasets
end


"""
    cleanup()

Periodically delete datasets if retention time is exceeded or uploads failed.
"""
function cleanup()
    counter = 0
    while true
        ts = now()
        ds = read_datasets()
        counter += 1

        foreach(ds) do d
            if d.stage == available
                # soft delete DataSets which exceeded their retention time
                if d.timestamp_created + Hour(d.retention) < ts
                    @info "delete $(d.label), ID: $(d.id)"
                    delete_dataset_soft(d.id)
                end
            elseif d.stage == deleted
                # hard delete DataSets which were already soft deleted
                if d.timestamp_stagechange + Hour(config["retention"]["purge"]) < ts
                    @info "permanently delete $(d.label), ID: $(d.id)"
                    delete_dataset_hard(d.id)
                end
            elseif d.stage ∈ (initial, scanned, prepared)
                # hard delete DataSets wich got stuck in initial, scanned or prepared stage
                if d.timestamp_created + Day(1) < ts
                    @info "remove from tmp layer: $(d.label), ID: $(d.id)"
                    delete_dataset_hard(d.id)
                end
            end
        end

        if counter > 1000
            checkstorage()
            counter = 0
        end
        sleep(config["retention"]["interval"])
    end
end