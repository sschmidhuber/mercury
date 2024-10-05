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
function format_size(bytes::Union{Int,Int128})::String
    local size
    
    if bytes < 1024
        size = "$bytes B"
    elseif bytes < 1024^2
        rounded = round_sig(bytes/1024)
        size = "$rounded KiB"
    elseif bytes < 1024^3
        rounded = round_sig(bytes/1024^2)
        size = "$rounded MiB"
    elseif bytes < 1024^4
        rounded = round_sig(bytes/1024^3)
        size = "$rounded GiB"
    elseif bytes < 1024^5
        rounded = round_sig(bytes/1024^4)
        size = "$rounded TiB"
    elseif bytes < 1024^6
        rounded = round_sig(bytes/1024^5)
        size = "$rounded PiB"
    elseif bytes/1024^6 < 100
        rounded = round_sig(bytes/1024^6)
        size = "$rounded EiB"
    else
        rounded = round(Int, bytes/1024^6)
        size = "$rounded EiB"
    end

    return size
end


"""
    round_sig(x::Number)::String

Returns the given number as string, rounded to 3 significant digits and without trailing zeros.
"""
function round_sig(x::Number)::String
    @sprintf "%g" round(x, sigdigits=3)
end



"""
    storage_size(ds::DataSet)

Returns the storage size of all files of a DataSet in bytes. Even if not all files or chunks were downloaded, yet.
"""
function storage_size(ds::DataSet)
    [file.size for file=ds.files] |> sum
end


"""
    download_uri(ds::DataSet)

Return the URI of the given DataSet.
"""
function download_uri(ds::DataSet)
    directory  = "/live/" * string(ds.id) * "/"
    filename = length(ds.files) == 1 && ds.files[1].directory |> isempty ? ds.files[1].name : replace(ds.label, '/' => '-') * ".zip"

    return directory * filename
end


"""
    download_filename(ds::DataSet)

Returns the download file name of a given DataSet.
"""
function download_filename(ds::DataSet)::String
    length(ds.files) == 1 && ds.files[1].directory |> isempty ? ds.files[1].name : "$(replace(ds.label, '/' => '-')).zip"
end