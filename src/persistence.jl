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
            open(joinpath(path, ds.filename[i]),"w") do p
                write(p, iobuffers[i])
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


"""
    delete_dataset(id::UUID)

Delete the DataSet corresponding to the given ID, do nothing if the id was not found.
"""
function delete_dataset(id::UUID)
    lock(dslock)
    try
        if haskey(datasets, id)
            delete!(datasets, id)
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
end