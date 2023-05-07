"""
    SubnetRestrictionMiddleware(handler)

Application level middleware to restrict requests from outside the configured subnets.
By default only loopback and private IPv4 subnets are allowed.
"""
function SubnetRestrictionMiddleware(handler)
    subnets = map(config["network"]["subnets"]) do subnet
        IPv4Net(subnet)
    end

    return function(req::HTTP.Request)
        clientip = req.context[:ip]
        
        n = @chain subnets begin
            clientip .∈ _
            sum(_)
        end

        if n == 0
            @info "access attempt from: \"$clientip\", request denied"
            return HTTP.Response(403, "Access denied")
        else
            return handler(req)
        end        
    end
end