#! /usr/bin/env julia

module Mercury

# https://xkcd.com/949/

using Dates, UUIDs, MIMEs, TOML, Chain, JSON, Dash

cd(@__DIR__)
const config = TOML.parsefile("../config/config.toml")

include("model.jl")
include("service.jl")
include("view.jl")

run_server(app, config["network"]["ip"], config["network"]["port"]; debug=config["debug"])

end