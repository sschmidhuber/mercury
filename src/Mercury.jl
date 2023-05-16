#! /usr/bin/env -S julia -t auto

module Mercury

#=

https://xkcd.com/949/

TODOs:
* protect against large uploads

* client side config (disable upload for externals)
* copy and share download link
* search data sets, get hidden data sets by ID
* disable upload for external clients
* write API tests for public / hidden flags
* external access support (download)
* external access support (upload)
* client side upload limit
* sort datasets
* link sharing
* add settings to upload (retention time, visibility)
* short dataset ID and copy dataset ID to clipboard
* icons / thumbnails
* search datasets
* number of files, file types and more meta data of datasets
* QR code
* show dataset after upload, directly in upload page
* data set content details / file list
* large dataset / file support (https://stackoverflow.com/questions/50121917/split-an-uploaded-file-into-multiple-chunks-using-javascript)
* back to top button
* load more (pagination)
* user info / welcome dialog
* create setup script (load fonrend and backend dependencies)
* create storage init function (create tmp/live directories)
* bucket / directories to seperate data sets and access to buckets / directories
* version support for uploading same data set multiple times

=#


cd(@__DIR__)
using Pkg
Pkg.activate("..")
using Dates, UUIDs, MIMEs, TOML, Chain, JSON, HTTP, Oxygen, Mmap, LoggingExtras, Sockets, IPNets

const config = TOML.parsefile("../config/config.toml")


include("model.jl")
include("persistence.jl")
include("service.jl")
include("common.jl")
include("middleware.jl")
include("api.jl")


function init()
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
end

function start_webserver()
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
    init()
    start_webserver()
else
    init()
end


end