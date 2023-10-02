#! /usr/bin/env -S julia -t auto

module Mercury

#=

https://xkcd.com/949/

TODOs:
* remove / work around memory leaks
* create secure context to support share and clipboard APIs
* copy and share download link
* short dataset ID and copy dataset ID to clipboard
* migrate from JSON to Serialization ? for storing flat file DB?
* disable malware check more elegant
* dispatch event to trigger toast message
* manual delete, if no retention period is set
* rewrite fonrend as SPA following modern JavaScript style
* large dataset / file support (https://stackoverflow.com/questions/50121917/split-an-uploaded-file-into-multiple-chunks-using-javascript)
* search data sets, get hidden data sets by ID
* write API tests for public / hidden flags
* external access support (download)
* external access support (upload)
* add files to existing dataset
* video player
* image viewer
* document viewer
* audio player
* client side upload limit
* don't allow public data sets if the option is not set in config
* sort datasets
* link sharing
* use LOAD_PATH in future if parts are to be split into modules
* icons / thumbnails
* search datasets
* number of files, file types and more meta data of datasets
* QR code
* data set content details / file list* back to top button
* load more (pagination)
* view images, videos, docuemnts, listen music of data sets
* user info / welcome dialog
* create setup script (load fonrend and backend dependencies)
* create storage init function (create tmp/live directories)
* bucket / directories to seperate data sets and access to buckets / directories
* version support for uploading same data set multiple times
* add sceleton for not yet loaded content, e.g. datasets and system status

=#


cd(@__DIR__)
using Pkg
Pkg.activate("..")
Pkg.instantiate()
using Dates, UUIDs, MIMEs, TOML, Chain, JSON, HTTP, Oxygen, Mmap, LoggingExtras, Sockets, IPNets, SystemStats

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

function start_webserver(async=true)
    # start webserver
    host=config["network"]["ip"]
    port=config["network"]["port"]
    middleware = [ip_segmentation]

    if Threads.nthreads() == 1
        if config["disable_access_log"]
            serve(middleware=middleware, host=host, port=port, access_log=nothing, async=async)
        else
            serve(middleware=middleware, host=host, port=port, async=async)
        end
    else
        if config["disable_access_log"]
            serveparallel(middleware=middleware, host=host, port=port, access_log=nothing, async=async)
        else
            serveparallel(middleware=middleware, host=host, port=port, async=async)
        end        
    end
end

function stop_webserver()
    terminate()
end

function restart_webserver(async=true)
    stop_webserver()
    start_webserver(async)
end

if isinteractive()
    init()
    try
        start_webserver(true)
    catch e
        if e isa Base.IOError
            @info "port already in use, restart server"
            restart_webserver(true)
        else
            stop_webserver()
            showerror(stderr, e)
        end
    end
else
    init()
    start_webserver(false)
end


end