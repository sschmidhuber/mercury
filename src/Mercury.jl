#! /usr/bin/env julia

module Mercury

# https://xkcd.com/949/

cd(@__DIR__)
using Pkg
Pkg.activate("..")
using Dates, UUIDs, MIMEs, TOML, Chain, JSON, HTTP, Oxygen, Mmap

const config = TOML.parsefile("../config/config.toml")


include("model.jl")
include("persistence.jl")
include("service.jl")
include("api.jl")

function main()
    # check config
    if config["skip_malware_check"] == true
        @warn "malware protection is disabled"
    end

    # initialize flat file DB
    initdb()

    # start periodic cleanup
    @async cleanup()

    # start webserver
    host=config["network"]["ip"]
    port=config["network"]["port"]

    if Threads.nthreads() == 1
        serve(host=host, port=port)
    else
        serveparallel(host=host, port=port)
    end
end

if !isinteractive()
    main()
end


end