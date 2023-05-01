"""
    add_dataset(id::UUID, filename::Vector{AbstractString}, type::Vector{MIME}, files)

Add a new Data Set
"""
function add_dataset(id::UUID, label::String, filenames::Vector{String}, types::Vector{T} where T <: MIME, sizes::Vector{Int}, iobuffers)
    ds = DataSet(id, strip(label), [], filenames, config["retention"]["default"], types, sizes)
    create_dataset(ds, iobuffers)
end


"""
    process_dataset(id::UUID)

Process a newly uploaded dataset.
"""
function process_dataset(id::UUID)
    if malwarescan(id)
        promote_dataset(id)
    end
end


"""
    malwarescan(id::UUID)

Returns true, if scan was successful (no malware found) or false if test failed or malware was detected.
In case malware was found, the data will be deleted immediately.
"""
function malwarescan(id::UUID)
    try
        ds = read_dataset(id)
        if isnothing(ds)
            @warn "no files found corresponding to ID: $id"
            return false
        end
        if config["skip_malware_check"] == true
            @warn "skip malware check for: $id"
            ds.stage = scanned
            ds.stagechange = now()
            update_dataset(ds)
            return true
        else
            dir = joinpath(config["storage_dir"], "tmp", string(id))
            try
                run(`clamscan -ri --no-summary $dir`)
                ds.stage = scanned
                ds.stagechange = now()
                update_dataset(ds)
                return true
            catch _
                @warn "malware check failed for: $id"
                delete_dataset(id, hard = true)
                return false
            end
        end
    catch _
        @warn "malware check failed"
        return false
    end        
end


"""
    format_size(bytes::Int)::String

Translates a given number of bytes into a easily human readable form of e.g. KiB, MiB, GiB,...
"""
function format_size(bytes::Int)::String
    local size
    
    if bytes < 1024
        size = "$bytes B"
    elseif bytes < 1024^2
        bytes = round(bytes/1024) |> Int
        size = "$bytes KiB"
    elseif bytes < 1024^3
        bytes = round(bytes/1024^2) |> Int
        size = "$bytes MiB"
    elseif bytes < 1024^4
        bytes = round(bytes/1024^3) |> Int
        size = "$bytes GiB"
    elseif bytes < 1024^5
        bytes = round(bytes/1024^4) |> Int
        size = "$bytes TiB"
    elseif bytes < 1024^6
        bytes = round(bytes/1024^5) |> Int
        size = "$bytes PiB"
    else
        bytes = round(bytes/1024^6) |> Int
        size = "$bytes EiB"
    end

    return size
end

"""
    format_period(timestamp::DateTime)::String

Translates a given retention time stamp into time left, e.g. "2 days"
"""
function format_retention(timestamp::DateTime)::String
    current_time = now()
    local period

    if round(timestamp - current_time, Week) > Week(52)
        period = "more than a year"
    elseif round(timestamp - current_time, Day) > Day(21)
        period = round(timestamp - current_time, Week) |> string
    elseif round(timestamp - current_time, Hour) > Hour(48)
        period = round(timestamp - current_time, Day) |> string
    elseif round(timestamp - current_time, Minute) > Minute(120)
        period = round(timestamp - current_time, Hour) |> string
    elseif round(timestamp - current_time, Second) > Second(55)
        period = round(timestamp - current_time, Minute) |> string
    elseif round(timestamp - current_time, Second) >= Second(0)
        period = "less than a minute"
    else
        period = "retention time expired"
    end

    return period
end


"""
    properties(id::UUID)

Return properties of the data set associated to the given ID.
"""
function properties(id::UUID)
    ds = read_dataset(id)
    if isnothing(ds)
        return nothing
    end
    size = format_size(ds.sizes |> sum)
    time_left = format_retention(ds.timestamp + Hour(ds.retention))
    download_extension = if ds.filenames |> length > 1
        ".zip"
    else
        extension_from_mime(ds.types[1])
    end

    Dict(
        "id" => id,
        "label" => ds.label,
        "tags" => ds.tags,
        "stage" => ds.stage,
        "files" => ds.filenames,
        "types" => ds.types,
        "download_extension" => download_extension,
        "size_total" => size,
        "timestamp" => ds.timestamp,
        "retention_time" => ds.retention,
        "time_left" => time_left,
        "downloads" => ds.downloads
    )
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
    used_storage = map(d -> sum(d.sizes), ds) |> sum
    min(diskstat(config["storage_dir"]).available, config["limits"]["storage"] - used_storage)
end


"""
    status()

Return system status.
"""
function status()
    ds = read_datasets()    
    count_ds = filter(x -> x.stage == available, ds) |> length
    count_files = @chain ds begin
        filter(x -> x.stage == available, _)
        map(d -> length(d.filenames), _)
        sum(_)
    end
    used_storage = map(d -> sum(d.sizes), ds) |> sum
    available_storage = min(diskstat(config["storage_dir"]).available, config["limits"]["storage"] - used_storage)
    total_storage = available_storage + used_storage
    used_relative = used_storage / total_storage * 100 |> round |> Int

    Dict(
        "count_datasets" => count_ds,
        "count_files" => count_files,
        "used_storage" => format_size(used_storage),
        "available_storage" => format_size(available_storage),
        "total_storage" => format_size(total_storage),
        "used_relative" => "$used_relative %"
    )
end


function limits()
    Dict(
        "filesize" => config["limits"]["filesize"],
        "filesize_pretty" => config["limits"]["filesize"] |> format_size,
        "filenumber_per_dataset" => config["limits"]["filenumber_per_dataset"],
        "datasetsize" => config["limits"]["datasetsize"],
        "datasetsize_pretty" => config["limits"]["datasetsize"] |> format_size,
        "datasetnumber" => config["limits"]["datasetnumber"]
    )
end


"""
    available_datasets()

Return status of all available datasets.
"""
function available_datasets()
    ds = read_datasets()
    ds_status = map(d -> properties(d.id), ds)
    filter(d -> d["stage"] == available, ds_status)
end


"""
    download_path(id::UUID)

Return the path of the correspoonding download artefact associated to the given ID.
Return nothing, if there is no data set corresponding to the given ID.
"""
function get_download_path(id::UUID)
    ds = read_dataset(id)
    if isnothing(ds) || ds.stage != available
        return nothing
    end

    livepath = joinpath(config["storage_dir"], "live", string(id))
    filename = length(ds.filenames) == 1 ? ds.filenames[1] : ds.label * ".zip"

    ds.downloads += 1
    update_dataset(ds)

    return joinpath(livepath, filename)
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