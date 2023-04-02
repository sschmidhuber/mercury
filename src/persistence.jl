const dbpath = joinpath(config["db_dir"], "database.json")
datasets = nothing
dslock = ReentrantLock()


"""
    create_dataset(ds::DataSet)

Create a new DataSet.
"""
function create_dataset(ds::DataSet, iobuffers)
    path = joinpath(config["storage_dir"], "tmp", string(ds.id))
    try
        mkpath(path)        
    catch e
        showerror(stderr, e)
        throw(ErrorException("failed to create tmp directory for \"$(ds.id)\""))
    end

    try
        for i in eachindex(iobuffers)
            open(joinpath(path, ds.filenames[i]),"w") do p
                write(p, iobuffers[i])
                close(iobuffers[i])
            end
        end
    catch e
        showerror(stderr, e)
        throw(ErrorException("failed to write data of \"$(ds.id)\" to disk"))
    end

    lock(dslock)
    try
        datasets[ds.id] = ds
        storeds()
    finally
        unlock(dslock)
    end
end


"""
    read_dataset(id::UUID)::Union{DataSet,Nothing}

Return DataSet with given ID or nothing, if the ID was not found.
"""
function read_dataset(id::UUID)::Union{DataSet,Nothing}
    lock(dslock)
    try
        if haskey(datasets, id)
            return deepcopy(datasets[id])
        else
            return nothing
        end        
    finally
        unlock(dslock)
    end
end


"""
    read_datasets()::Vector{DataSet}

Return a Vector of all DataSets or an empty Vector if there are no DataSets.
"""
function read_datasets()::Vector{DataSet}
    lock(dslock)
    try
        if isempty(datasets)
            return Vector{DataSet}()
        else
            return deepcopy(values(datasets) |> collect)
        end
    finally
        unlock(dslock)
    end    
end


"""
    update_dataset(ds::DataSet)

Update a DataSet, if there is no DataSet with the given ID a error will be thrown.
"""
function update_dataset(ds::DataSet)
    lock(dslock)
    try
        if haskey(datasets, ds.id)
            if !isequal(datasets[ds.id],ds)
                datasets[ds.id] = ds
                storeds()                
            end
        else
            throw(DomainError(ds.id |> string, "Invalid ID, DataSet not found"))
        end
    finally
        unlock(dslock)
    end
end


function promote_dataset(id::UUID)
    local ds
    if haskey(datasets, id)
        ds = datasets[id]
    else
        throw(DomainError(id |> string, "Invalid ID, DataSet not found"))
    end

    if ds.stage != scanned
        throw(DomainError(ds.stage, "Invalid stage, \"scanned\" expected"))            
    end

    tmppath = joinpath(config["storage_dir"], "tmp", string(id))
    livepath = joinpath(config["storage_dir"], "live", string(id))
    mkpath(livepath)

    if ds.filenames |> length == 1
        mv(joinpath(tmppath, ds.filenames[1]), joinpath(livepath, ds.filenames[1]))
    else
        run(Cmd(`zip -0 -q $(ds.label).zip $(ds.filenames)`, dir=tmppath))
        mv(joinpath(tmppath, "$(ds.label).zip"), joinpath(livepath, "$(ds.label).zip"))
    end

    lock(dslock)
    try
        rm(tmppath, recursive=true)

        ds.stage = available
        storeds()
    catch e
        showerror(stderr, e)
        throw(ErrorException("DataSet promotion failed for: $id"))
    finally
        unlock(dslock)
    end
end


"""
    delete_dataset(id::UUID)

Delete the DataSet corresponding to the given ID, do nothing if the id was not found.
If purge = true is passed, the DB entry will not only be set to deleted, but the record will
be deleted from the DB.

In any case the files related to the DataSet will be deleted from disk.
"""
function delete_dataset(id::UUID; purge=false)
    lock(dslock)
    try
        if haskey(datasets, id)
            tmppath = joinpath(config["storage_dir"], "tmp", string(id))
            rm(tmppath, force=true, recursive=true)

            livepath = joinpath(config["storage_dir"], "live", string(id))
            rm(livepath, force=true, recursive=true)

            if purge
                delete!(datasets, id)
            else
                datasets[id].stage = deleted
            end
            storeds()
        end
    finally
        unlock(dslock)
    end
end


"""
    storeds()

Store the current state of Data Sets within its JSON structure to disk. Before executing
this function the dslock has to be aquired by the caller.
"""
function storeds()
    open(dbpath,"w") do f
        write(f,JSON.json(datasets))
    end
end


"""
    checkds(ds::DataSet)

Check the consistency of a given Data Set.
"""
function checkds(ds::DataSet)
    tmppath = joinpath(config["storage_dir"], "tmp", string(ds.id))
    livepath = joinpath(config["storage_dir"], "live", string(ds.id))

    if ds.stage == deleted
        if ispath(tmppath)
            @warn "$(ds.label) - $(ds.stage): inconsistend data found"
            rm(tmppath, recursive=true)
        end
        if ispath(livepath)
            @warn "$(ds.label) - $(ds.stage): inconsistend data found"
            rm(livepath, recursive=true)
        end
    elseif ds.stage == available
        if ispath(tmppath)
            @warn "$(ds.label) - $(ds.stage): inconsistend data found"
            rm(tmppath, recursive=true)
        end
    elseif ds.stage == initial
        if ispath(livepath)
            @warn "$(ds.label) - $(ds.stage): violation of data lifecycle constraint found"
            rm(livepath, recursive=true)
        end
    end
end


"""
    removeds(id::UUID)

Remove all artifacts of a inconsistent Data Set, on logical and physical level.
"""
function removeds(id::UUID)
    tmppath = joinpath(config["storage_dir"], "tmp", string(id))
    livepath = joinpath(config["storage_dir"], "live", string(id))
    delete!(datasets, id)
    rm(tmppath, force=true, recursive=true)
    rm(livepath, force=true, recursive=true)
end


function checkstorage()
    tmppath = joinpath(config["storage_dir"], "tmp")
    livepath = joinpath(config["storage_dir"], "live")

    foreach(readdir(tmppath)) do id
        if haskey(datasets, UUID(id))
            ds = datasets[UUID(id)]
            if !(ds.stage == initial || ds.stage == scanned)
                @warn "$(ds.label) - $(ds.stage): inconsistend DB record found"
                removeds(ds.id)
            end
        else
            @warn "$id: orphaned data set found"
            removeds(UUID(id))
        end
    end

    foreach(readdir(livepath)) do id
        if haskey(datasets, UUID(id))
            ds = datasets[UUID(id)]
            if !(ds.stage == available || ds.stage == scanned)
                @warn "$(ds.label) - $(ds.stage): inconsistend DB record found"
                removeds(ds.id)
            end
        else
            @warn "$id: orphaned data set found"
            removeds(UUID(id))
        end
    end
end


"""
    correct_inconsistencies()

Correct inconsistencies in the logical Data Set representations and physically stored data sets.
"""
function correct_inconsistencies()
    lock(dslock)
    try
        # check database
        foreach(values(datasets)) do ds
            checkds(ds::DataSet)
        end

        # check storage
        checkstorage()
    finally
        unlock(dslock)
    end
end

"""
    initdb()

Initialize flat file DB at application start. This function need to be called before the
first read / write access to DB.
"""
function initdb()
    lock(dslock)
    @info "initialize flat file DB"
    try
        if isfile(dbpath)
            tmp = read(dbpath, String) |> JSON.parse
            if isempty(tmp)
                global datasets = Dict{UUID, DataSet}()
                @info "DB is empty"
            else
                global datasets = tmp |> unmarshal_dataset
                @info "$(length(datasets)) records found"
            end
        else
            global datasets = Dict{UUID, DataSet}()
            storeds()
            @info "new DB file created"
        end
    finally
        unlock(dslock)
    end

    correct_inconsistencies()
end