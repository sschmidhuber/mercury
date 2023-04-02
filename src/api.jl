@dynamicfiles "client" "web"


@get "/" function()
    redirect("web/index.html")
end


@get "/status" function(req)
    status()
end


@post "/datasets" function(req)
    contenttype = HTTP.headers(req, "Content-Type")
    if isempty(contenttype) || !contains(contenttype[1], "multipart/form-data")
        return HTTP.Response(415, Dict("error" => "invalid Content-Type", "detail" => "Expect \"multipart/form-data\"") |> JSON.json)
    end

    content = HTTP.parse_multipart_form(req)
    if content |> isnothing
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "parsing multipart form failed") |> JSON.json)
    end
    id = uuid4()    
    label = content[1].data.data |> String
    if label == ""
        label = "Data Set $(today())"
    end

    filenames = map(c -> c.filename, content[2:end])
    types = map(c -> c.contenttype |> MIME, content[2:end])
    iobuffers = map(c -> c.data, content[2:end])
    sizes = map(io -> bytesavailable(io), iobuffers)

    if isempty(iobuffers)
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "file missing") |> JSON.json)
    end
    if isempty(filenames) || filenames[1] == ""
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "filename missing") |> JSON.json)
    end

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
    return HTTP.Response(200, data)
end


@get "/datasets/{id}/status" function(req, id::String)
    try
        dsid = UUID(id)
    catch
        return HTTP.Response(422, Dict("error" => "invalid request", "detail" => "$id is not a valid UUID") |> JSON.json)
    end
    res = status(UUID(id))
    if isnothing(res)
        return HTTP.Response(404, Dict("error" => "no DataSet with ID: $id found") |> JSON.json)
    end

    return res
end