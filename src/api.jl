@dynamicfiles "../static" "web"


@get "/" function()
    redirect("web/index.html")
end

@post "/dataset" function(req)
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

    add_dataset(id, label, filenames, types, sizes, iobuffers)

    return "uploaded as new data set: $id"
end