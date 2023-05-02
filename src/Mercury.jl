#! /usr/bin/env -S julia -t auto

module Mercury

#=

https://xkcd.com/949/

TODOs:
* log to file
* protect against large uploads
* display system status only after response
* create storage init function (create tmp/live directories)
* sort datasets
* create setup script (load fonrend and backend dependencies)
* add settings to upload
* link sharing

=#


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