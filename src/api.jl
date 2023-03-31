@dynamicfiles "../static" "web"


@get "/" function()
    redirect("web/index.html")
end

@post "/datasets" function(req)
    contenttype = HTTP.headers(req, "Content-Type")
    if isempty(contenttype) || !contains(contenttype[1], "multipart/form-data")
        return HTTP.Response(415, Dict("error" => "invalid Content-Type", "detail" => "Expect \"multipart/form-data\""))
    end

    content = HTTP.parse_multipart_form(req)
    if content |> isnothing
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "parsing multipart form failed"))
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

    if filenames[1] == ""
        return HTTP.Response(422, Dict("error" => "invalid request content"))
    end

    add_dataset(id, label, filenames, types, sizes, iobuffers)
    @async process_dataset($id)

    return ("id" => id)
end


@get "/datasets/status" function(req)
    status()
end


@get "/datasets/{id}/status" function(req, id::String)
    res = status(UUID(id))
    if isnothing(res)
        return HTTP.Response(404, Dict("error" => "no DataSet with ID: $id found"))
    end

    return res
end