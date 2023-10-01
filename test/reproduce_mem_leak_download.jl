using Oxygen, HTTP, Profile, Mmap, MIMEs

# Oxygen
@get "/oxygen" function(req)    
    open("/home/stefan/Fedora-Workstation-Live-x86_64-38-1.6.iso") do stream
        data = Mmap.mmap(stream, Array{UInt8,1})
        headers = [
            "Transfer-Encoding" => "chunked",
            "Content-Disposition" => "attachment; filename=\"Fedora-Workstation-Live-x86_64-38-1.6.iso\"",
            "Content-Type" => mime_from_extension(".iso")
        ]
        return HTTP.Response(200, headers, data)
    end    
end


#= HTTP 
function example(req::HTTP.Request)
    @info "request handled, \"Ping!\""
    return HTTP.Response(201, "Ping!")
end

const router = HTTP.Router()
HTTP.register!(router, "POST", "/", example)=#

@info "start server"
serve(async=true)
#HTTP.serve!(router, HTTP.Sockets.localhost, 8080)




#@info "force GC run"
#GC.gc()

@info "create heap snapshot"
Profile.take_heap_snapshot("/home/stefan/mem.heapsnapshot")