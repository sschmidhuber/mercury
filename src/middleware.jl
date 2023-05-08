"""
    SubnetRestriction(handler)

Middleware to enforce IP restriction configuration and flag requests accordingly as "internal" or "external".
"""
function ip_segmentation(handler)
    local subnets
    try
        subnets = map(subnet -> IPv4Net(subnet), config["network"]["internal_subnets"])
    catch _
        @error "invalid configuration: \"subnets\""
        terminate()
    end    
    
    local allow_external_access
    try
        allow_external_access = config["network"]["allow_external_access"]
    catch _
        @warn "invalid configuration: \"allow_external_access\""
        allow_external_access = false
    end

    return function(req::HTTP.Request)
        clientip = req.context[:ip]
        
        n = @chain subnets begin
            clientip .∈ _
            sum(_)
        end

        if n == 1
            req.context[:internal] = true
            return handler(req)
        elseif n == 0 && allow_external_access
            req.context[:internal] = false
            return handler(req)
        else
            @info "access attempt from: \"$clientip\", request denied"
            sleep(5)
            return HTTP.Response(403, "Access denied")
        end        
    end
end


"""
    internal(handler)

Middleware to restrict access to internal clients only.
"""
function internal(handler)
    return function(req::HTTP.Request)
        if req.context[:internal]
            @info "internal client IP"
            return handler(req)
        else
            clientip = req.context[:ip]
            @info "unauthorized access attempt from: \"$clientip\", request denied"
            sleep(5)
            return HTTP.Response(403, "Access denied")
        end
    end
end