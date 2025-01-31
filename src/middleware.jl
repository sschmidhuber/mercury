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
        @info "external access allowed: $allow_external_access"
    catch _
        @warn "invalid configuration: \"allow_external_access\""
        allow_external_access = false
    end

    return function(req::HTTP.Request)
        local clientip

        xrealip_header = filter(x -> first(x) == "X-Real-IP", req.headers)
        
        if isempty(xrealip_header)
            @error "\"X-Real-IP\" header not found. Ensure the reverse proxy sets the correct remote address."
            return HTTP.Response(500, "Missing header, wrong proxy configuration")
        else
            xrealip = only(xrealip_header).second
            try
                clientip = if 7 <= length(xrealip) <= 15
                    IPv4(xrealip)
                elseif 39 <= length(xrealip) <= 45
                    IPv6(xrealip)
                else
                    @error "invalid X-Real-IP address: $xrealip"
                    return HTTP.Response(500, "Invalid address, wrong proxy configuration")
                end
            catch e
                @error "invalid \"X-Real-IP\" header: $xrealip_header"
                return HTTP.Response(500, "Invalid header, wrong proxy configuration")
            end
        end
        
        # clientip is an element of n specified subnets
        n = mapreduce(net -> clientip ∈ net, +, subnets)

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