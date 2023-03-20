@dynamicfiles "../static" "web"


@get "/" function()
    redirect("web/index.html")
end

@post "/dataset" function(req)
    fileid = uuid4()
    content = HTTP.parse_multipart_form(req)
    name = content[1].filename
    type = content[1].contenttype
    open(joinpath("..", "data", "tmp", string(fileid)),"w") do f
        write(f, content[1].data)
    end
    return "file uploaded"
end