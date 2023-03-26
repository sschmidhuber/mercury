@dynamicfiles "../static" "web"


@get "/" function()
    redirect("web/index.html")
end

@post "/dataset" function(req)
    contenttype = HTTP.headers(req, "Content-Type")
    if isempty(contenttype) || !contains(contenttype[1], "multipart/form-data")
        @info "invalid Content-Type at POST /dataset"
        return HTTP.Response(415, "Expect \"multipart/form-data\" request")
    end

    content = HTTP.parse_multipart_form(req)
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
        @info "invalid request content"
        return HTTP.Response(422, "invalid request content")
    end

    add_dataset(id, label, filenames, types, sizes, iobuffers)
    @async process_dataset($id)

    return JSON.json("id" => id)
end