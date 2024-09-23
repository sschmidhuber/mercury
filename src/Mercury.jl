module Mercury

#=

https://xkcd.com/949/

TODOs:
* Fix Tests use testunits integrated with VS Code
* ensure packages are instantiated in correct versions, check how that works
* migrate FE to htmx
* add files to existing dataset
* resume uploads
* migrate from JSON to SQLite
* copy dataset ID to clipboard
* disable malware check more elegant
* load test / large file test
* dispatch event to trigger toast message
* manual delete, if no retention period is set
* search data sets, get hidden data sets by ID
* write API tests for public / hidden flags
* external access support (download)
* external access support (upload)
* push notifications about newly uploaded DataSets (push API)
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


using Chain
using Dates
using HTTP
using IPNets
using JSON
using LoggingExtras
using MIMEs
using Mmap
using Oxygen
using Printf
using Sockets
using SystemStats
using TOML
using UUIDs

cd(@__DIR__)

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


if haskey(ENV, "MODE")
    if ENV["MODE"] == "test"    # this mode is used for automated tests
        @info "run test mode"
    else
        @error "unknown mode $(ENV["MODE"])"
    end
elseif isinteractive()  # this mode is used for development
    @info "run interactive mode"
    init()
    try
        start_webserver(true)
    catch e
        if e isa Base.IOError
            @info "port already in use, restart server"
            restart_webserver(true)
        else
            @error "unexpected error"
            showerror(stderr, e)
            stop_webserver()
        end
    end    
else    # bootstrap Mercury
    init()
    start_webserver(false)
end


end