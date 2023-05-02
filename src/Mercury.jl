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
using Dates, UUIDs, MIMEs, TOML, Chain, JSON, HTTP, Oxygen, Mmap, LoggingExtras

const config = TOML.parsefile("../config/config.toml")


include("model.jl")
include("persistence.jl")
include("service.jl")
include("api.jl")

function main()
    # setup logging
    if !isinteractive()
        mkpath(dirname(config["logfile"]))
        logfile = open(config["logfile"], "w")
        dateformat = DateFormat("yyyy-mm-dd -- HH:MM:SS")
        logger = FormatLogger(logfile) do logfile, args
            println(logfile, args.level, " -- ", Dates.format(now(), dateformat), ": ", args.message, "  (", args._module, ":", args.line, ")")
        end
        logger = MinLevelLogger(logger, Logging.Info)
        global_logger(logger)
    end

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