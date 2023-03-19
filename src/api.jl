@dynamicfiles "../static" "web"


@get "/" () -> begin
    redirect("web/index.html")
end