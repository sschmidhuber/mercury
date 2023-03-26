#! /usr/bin/env julia

module Mercury

# https://xkcd.com/949/

cd(@__DIR__)
using Pkg
Pkg.activate("..")
using Dates, UUIDs, MIMEs, TOML, Chain, JSON, HTTP, Oxygen

const config = TOML.parsefile("../config/config.toml")


include("model.jl")
include("persistence.jl")
include("service.jl")
include("api.jl")

function main()
    # initialize flat file DB
    initdb()

    # start webserver
    serve(host=config["network"]["ip"], port=config["network"]["port"])
end

#if !isinteractive()
    main()
#end


end