#! /usr/bin/env julia

module Mercury

# https://xkcd.com/949/

cd(@__DIR__)
using Pkg
Pkg.activate("..")
using Dates, UUIDs, MIMEs, TOML, Chain, JSON, HTTP, Oxygen

const config = TOML.parsefile("../config/config.toml")
datasets = nothing
dslock = ReentrantLock()

include("model.jl")
include("service.jl")
include("api.jl")

function initdb()
    dbpath = joinpath(config["db_dir"], "database.json")
    lock(dslock)
    try
        if isfile(dbpath)
            global datasets = read(dbpath, String) |> JSON.parse
            if !isempty(datasets)
                global datasets = datasets |> dataset
            end
        else
            global datasets = Dict{UUID, DataSet}()
            storeds()
        end
    finally
        unlock(dslock)
    end
end

function main()
    # initialize flat file DB
    initdb()

    # start webserver
    serve(host=config["network"]["ip"], port=config["network"]["port"])
end

if !isinteractive()
    main()
end


end