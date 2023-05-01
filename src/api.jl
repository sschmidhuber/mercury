#@dynamicfiles "client" "web"
dynamicfiles("client", "web")


@get "/" function()
    redirect("web/index.html")
end


@get "/status" function(req)
    status()
end


@get "/limits" function(req)
    limits()
end


@post "/datasets" function(req)
    # validate request
    contenttype = HTTP.headers(req, "Content-Type")
    if isempty(contenttype) || !contains(contenttype[1], "multipart/form-data")
        return HTTP.Response(415, Dict("error" => "invalid Content-Type", "detail" => "Expect \"multipart/form-data\"") |> JSON.json)
    end

    content = HTTP.parse_multipart_form(req)
    if content |> isnothing
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "parsing multipart form failed") |> JSON.json)
    end

    # process request
    id = uuid4()
    filenames = map(c -> c.filename, content[2:end])
    types = map(c -> c.contenttype |> MIME, content[2:end])
    iobuffers = map(c -> c.data, content[2:end])
    sizes = map(io -> bytesavailable(io), iobuffers)

    label = content[1].data.data |> String
    if label == ""
        if length(filenames) == 1
            label = filenames[1]
        else
            label = "Data Set $(today())"
        end
    end

    

    # validate fields
    if isempty(iobuffers)
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "file missing") |> JSON.json)
    end
    if isempty(filenames) || filenames[1] == ""
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "filename missing") |> JSON.json)
    end
    if length(filenames) > config["limits"]["filenumber_per_dataset"]
        return HTTP.Response(413, Dict("error" => "dataset exceeds max file number", "detail" => "dataset exceeds max file number of $(config["limits"]["filenumber_per_dataset"])") |> JSON.json)
    end
    for i in eachindex(sizes)
        if sizes[i] > config["limits"]["filesize"]
            return HTTP.Response(413, Dict("error" => "file size exceeds limit", "detail" => "file size exceeds limit of $(config["limits"]["filesize"] |> format_size)") |> JSON.json)
        end
    end
    if sum(sizes) > config["limits"]["datasetsize"]
        return HTTP.Response(413, Dict("error" => "dataset exceeds size limit", "detail" => "dataset exceeds size limit of $(config["limits"]["datasetsize"] |> format_size)") |> JSON.json)
    end
    if 1 + count_ds() > config["limits"]["datasetnumber"]
        return HTTP.Response(507, Dict("error" => "maximum number of datasets exceeded", "detail" => "limit of $(config["limits"]["datasetnumber"]) datasets exceeded") |> JSON.json)
    end
    if sum(sizes) > available_storage()
        return HTTP.Response(507, Dict("error" => "storage limit exceeded", "detail" => "storage limit of $(config["limits"]["storage"] |> format_size) exceeded") |> JSON.json)
    end

    # add new DataSet and trigger further processing
    add_dataset(id, label, filenames, types, sizes, iobuffers)
    @async process_dataset($id)

    return HTTP.Response(201, Dict("id" => id) |> JSON.json)
end


@get "/datasets" function(req)
    available_datasets()
end


@get "/datasets/{id}" function(req, id)
    local dsid
    try
        dsid = UUID(id)
    catch
        return HTTP.Response(422, Dict("error" => "invalid request", "detail" => "$id is not a valid UUID") |> JSON.json)
    end

    # check authorization
    # to be implemented when introducinf protected / encrypted data sets and external access
    
    path = get_download_path(dsid)
    if isnothing(path)
        return HTTP.Response(404, Dict("error" => "resource not found", "detail" => "there is no data set available with ID: $id") |> JSON.json)
    end
    data = Mmap.mmap(open(path), Array{UInt8,1})
    props = properties(dsid)
    headers = [
        "Transfer-Encoding" => "chunked",
        "Content-Disposition" => "attachment; filename=\"$(props["label"])\"",
        "Content-Type" => mime_from_extension(props["download_extension"]),
        "Content-Length" => props["sizes"] |> sum
    ]
    return HTTP.Response(200, headers, data)
end


@get "/datasets/{id}/properties" function(req, id::String)
    try
        dsid = UUID(id)
    catch
        return HTTP.Response(422, Dict("error" => "invalid request", "detail" => "$id is not a valid UUID") |> JSON.json)
    end
    res = properties(UUID(id))
    if isnothing(res)
        return HTTP.Response(404, Dict("error" => "no DataSet with ID: $id found") |> JSON.json)
    end

    return res
end