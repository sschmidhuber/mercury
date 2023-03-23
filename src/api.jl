@dynamicfiles "../static" "web"


@get "/" function()
    redirect("web/index.html")
end

@post "/dataset" function(req)
    id = uuid4()
    content = HTTP.parse_multipart_form(req)
    filename = content[1].filename
    path = joinpath(config["storage_dir"], "tmp", string(id), filename)
    type = content[1].contenttype

    open(path,"w") do f
        write(f, content[1].data)
    end
    create_dataset(id, filename, type)

    return "uploaded as new data set: $id"
end