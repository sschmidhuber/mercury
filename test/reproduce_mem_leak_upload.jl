using Oxygen, HTTP, Profile

# Oxygen
@post "/" function(req)
    return HTTP.Response(201, "Ping!")
end


#= HTTP 
function example(req::HTTP.Request)
    @info "request handled, \"Ping!\""
    return HTTP.Response(201, "Ping!")
end

const router = HTTP.Router()
HTTP.register!(router, "POST", "/", example)=#

@info "start server"
#serve(async=true)
HTTP.serve!(router, HTTP.Sockets.localhost, 8080)



@info "send POST request"
data = Dict(
    "label" => "Large File",
    "file" => HTTP.Multipart("DVD Image", open("/home/stefan/Downloads/Fedora-Workstation-Live-x86_64-38-1.6.iso"), "application/octet-stream")
)
body = HTTP.Form(data)
HTTP.request("POST", "http://127.0.0.1:8080/", [], body)

@info "force GC run"
GC.gc()

@info "create heap snapshot"
Profile.take_heap_snapshot("/home/stefan/mem.heapsnapshot")