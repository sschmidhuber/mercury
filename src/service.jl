function create_dataset(id, filename, type)
    ds = DataSet(id=id, filename=filename, type=type)

    lock(dslock)
    try
        datasets[id] = ds
        storeds()
    finally
        unlock(dslock)
    end
end


"""
    storeds()

Store the current state of Data Sets within its JSON structure to disk. Before executing this function the dslock has to be aquired by the caller.
"""
function storeds()
    dbpath = joinpath(config["db_dir"], "database.json")
    open(dbpath,"w") do f
        write(f,JSON.json(datasets))
    end
end