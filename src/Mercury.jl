module Mercury

#=

https://xkcd.com/949/

TODOs:
* add files to existing dataset
* external access support (upload)
* update to latest Bootstrap version
    * add automatic dark mode
* improve upload status UX
* search data sets, get hidden data sets by ID
* set log level in config file
* performance tests
    * async DB / storage access
    * websockets vs HTTP
* use Oxygen CRON for scheduled jobs
* copy dataset ID to clipboard
* print function
* resume uploads
* disable malware check more elegant
* load test / large file test
* dispatch event to trigger toast message
* manual delete, if no retention period is set
* write API tests for public / hidden flags
* push notifications about newly uploaded DataSets (push API)
* video player
* image viewer
* document viewer
* audio player
* client side upload limit
* don't allow public data sets if the option is not set in config
* sort datasets
* implement Meryury client in Julia and use for API tests
* link sharing
* use LOAD_PATH in future if parts are to be split into modules
* icons / thumbnails
* search datasets
* number of files, file types and more meta data of datasets
* QR code
* data set content details / file list* back to top button
* load more (pagination)
* optimize cleanup() function, not to load all datasets into memory
* view images, videos, docuemnts, listen music of data sets
* user info / welcome dialog
* create setup script (load fontend and backend dependencies)
    * ensure packages are instantiated in correct versions, check how that works
* create storage init function (create tmp/live directories)
* bucket / directories to seperate data sets and access to buckets / directories
* version support for uploading same data set multiple times
* add sceleton for not yet loaded content, e.g. datasets and system status
* configureable actions / scripts for specific uploaded datasets (e.g. copy to ...)

=#


using Chain
using Dates
using HTTP
using IPNets
using JSON3
using LoggingExtras
using MIMEs
using Mustache
using Oxygen
using Printf
using Sockets
using SQLite
using SystemStats
using TOML
using DataFrames
using UUIDs


cd(@__DIR__)

const config = TOML.parsefile("../config/config.toml")

include("model.jl")
include("persistence.jl")
include("service.jl")
include("common.jl")
include("middleware.jl")
include("view.jl")
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
        logger = MinLevelLogger(logger, Logging.Debug)
        global_logger(logger)
    end

    # check config
    if config["skip_malware_check"] == true
        @warn "malware protection is disabled"
    end

    # start periodic cleanup
    @async cleanup()
end

function start_webserver(async=true)
    # start webserver
    host=config["network"]["ip"]
    port=config["network"]["port"]
    middleware = [ip_segmentation]

    if Threads.nthreads() == 1
        if config["disable_access_log"] && !isinteractive()
            serve(middleware=middleware, host=host, port=port, access_log=nothing, async=async)
        else
            serve(middleware=middleware, host=host, port=port, async=async)
        end
    else
        if config["disable_access_log"] && !isinteractive()
            serveparallel(middleware=middleware, host=host, port=port, access_log=nothing, async=async)
        else
            serveparallel(middleware=middleware, host=host, port=port, async=async)
        end        
    end
end

function stop_webserver()
    @info "stop Mercury webserver"
    terminate()
end

function restart_webserver(async=true)
    stop_webserver()
    start_webserver(async)
end

atexit(stop_webserver)

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