@dynamicfiles "../static" "web"


@get "/" function()
    redirect("web/index.html")
end

@post "/datasets" function(req)
    contenttype = HTTP.headers(req, "Content-Type")
    if isempty(contenttype) || !contains(contenttype[1], "multipart/form-data")
        @info "invalid Content-Type at POST /dataset"
        return HTTP.Response(415, "Expect \"multipart/form-data\" request")
    end

    content = HTTP.parse_multipart_form(req)
    if content |> isnothing
        @warn "failed to parse multipart form data"
        return HTTP.Response(422, "invalid request content")
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
        @warn "invalid request content"
        return HTTP.Response(422, "invalid request content")
    end

    add_dataset(id, label, filenames, types, sizes, iobuffers)
    @async process_dataset($id)

    return ("id" => id)
end

@get "/datasets/{id}/status" function(req, id::String)
    status(UUID(id))
end