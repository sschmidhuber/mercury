#! /usr/bin/env -S julia -t auto

module Mercury

#=

https://xkcd.com/949/

TODOs:
* protect against large uploads

* client side upload limit
* sort datasets
* link sharing
* add settings to upload (retention time, visibility)
* short dataset ID and copy dataset ID to clipboard
* icons / thumbnails
* search datasets
* number of files, file types and more meta data of datasets
* external access support
* QR code
* show dataset after upload, directly in upload page
* data set content details / file list
* large dataset / file support
* user info / welcome dialog
* create setup script (load fonrend and backend dependencies)
* create storage init function (create tmp/live directories)

=#


cd(@__DIR__)
using Pkg
Pkg.activate("..")
using Dates, UUIDs, MIMEs, TOML, Chain, JSON, HTTP, Oxygen, Mmap, LoggingExtras, Sockets, IPNets

const config = TOML.parsefile("../config/config.toml")


include("model.jl")
include("persistence.jl")
include("service.jl")
include("middleware.jl")
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
    middleware = [ip_segmentation]

    if Threads.nthreads() == 1
        if config["disable_access_log"]
            serve(middleware=middleware, host=host, port=port, access_log=nothing)
        else
            serve(middleware=middleware, host=host, port=port)
        end
    else
        if config["disable_access_log"]
            serveparallel(middleware=middleware, host=host, port=port, access_log=nothing)
        else
            serveparallel(middleware=middleware, host=host, port=port)
        end        
    end
end

if !isinteractive()
    main()
end


end