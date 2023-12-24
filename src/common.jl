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
    dataset_to_dict(ds::DataSet)::Dict

Export a dataset object into dict type and format fields to display on client side.

"""
function dataset_to_dict(ds::DataSet)::Dict
    size_total = ds.sizes |> sum
    time_left = ds.timestamp + Hour(ds.retention)
    download_extension = length(ds.filenames) == 1 && dirname(ds.filenames[1]) == "" ? extension_from_mime(ds.types[1]) : ".zip"
    download_filename = length(ds.filenames) == 1 && dirname(ds.filenames[1]) == "" ? ds.filenames[1] : ds.label * ".zip"
    download_url = (ds.public ? config["network"]["external_url"] : config["network"]["internal_url"]) * "/datasets/$(ds.id)"

    Dict(
        "id" => ds.id,
        "label" => ds.label,
        "public" => ds.public,
        "hidden" => ds.hidden,
        "tags" => ds.tags,
        "stage" => ds.stage,
        "files" => ds.filenames,
        "types" => ds.types,
        "sizes" => ds.sizes,
        "size_total" => size_total,
        "size_total_f" => size_total |> format_size,
        "timestamp" => ds.timestamp,
        "retention_time" => ds.retention,
        "time_left" => time_left,
        "time_left_f" => time_left |> format_retention,
        "downloads" => ds.downloads,
        "download_extension" => download_extension,
        "download_filename" => download_filename,
        "download_url" => download_url
    )
end


"""
    storage_size(ds::DataSet)

Returns the storage size of all files of a DataSet in bytes. Even if not all files or chunks were downloaded, yet.
"""
function storage_size(ds::DataSet)
    [file.size for file=ds.files] |> sum
end