"""
    add_dataset(id::UUID, filename::Vector{AbstractString}, type::Vector{MIME}, files)

Add a new Data Set
"""
function add_dataset(id::UUID, label::String, filename::Vector{String}, type::Vector{T} where T <: MIME, size::Vector{Int}, iobuffers)
    ds = DataSet(id=id, label=label, filename=filename, type=type, size=size)

    create_dataset(ds, iobuffers)
end


"""
    process_dataset(id::UUID)

Process a newly uploaded dataset.
"""
function process_dataset(id::UUID)
    @warn "malware check (not implemented yet, this is just mocked)"
    ds = read_dataset(id)
    # mock malware check
    sleep(1)
    ds.stage = scanned
    update_dataset(ds)

    @info "check DataSet consistency (not implemented yet)"
    # availability of all files in expected size and type

    @info "optimize storage (not implemented yet)"
    
    @info "prepare for download"
    promote_dataset(id)
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
        bytes = round(bytes/1024, digits=2)
        size = "$bytes KiB"
    elseif bytes < 1024^3
        bytes = round(bytes/1024^2, digits=2)
        size = "$bytes MiB"
    elseif bytes < 1024^4
        bytes = round(bytes/1024^3, digits=2)
        size = "$bytes GiB"
    elseif bytes < 1024^5
        bytes = round(bytes/1024^4, digits=2)
        size = "$bytes TiB"
    elseif bytes < 1024^6
        bytes = round(bytes/1024^5, digits=2)
        size = "$bytes PiB"
    else
        bytes = round(bytes/1024^6, digits=2)
        size = "$bytes EiB"
    end

    return size
end

"""
    format_period(timestamp::DateTime)::String

Translates a given retention time stamp into time left, e.g. "2 days"
"""
function format_period(timestamp::DateTime)::String
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
    else
        period = "less than a minute"
    end

    return period
end


function status(id::UUID)
    ds = read_dataset(id)
    if isnothing(ds)
        return nothing
    end
    size = format_size(ds.size |> sum)

    Dict(
        "id" => id,
        "label" => ds.label,
        "stage" => ds.stage,
        "files" => ds.filename,
        "size" => size,
        "timestamp" => ds.timestamp,
        "retention_time" => ds.retention
    )
end


function status()
    ds = read_datasets()
    
    count_ds = length(ds)
    count_files = map(d -> length(d.filename), ds) |> sum
    available_storage = diskstat(config["storage_dir"]).available
    used_storage = map(d -> sum(d.size), ds) |> sum
    total_storage = available_storage + used_storage
    used_relative = used_storage / total_storage * 100 |> round |> Int

    Dict(
        "count_datasets" => count_ds,
        "count_files" => count_files,
        "used_storage" => format_size(used_storage),
        "available_storage" => format_size( available_storage),
        "total_storage" => format_size(total_storage),
        "used_relative" => "$used_relative %"
    )
end