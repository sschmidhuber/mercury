
"""
    initdb()

Returns a SQLite DB connection object. If required a new DB is created.
In "test" mode, a in memory DB is used.
"""
function initdb()
    dbpath = joinpath(config["db_dir"], "mercury.db")
    local db

    if haskey(ENV, "MODE") && ENV["MODE"] == "test"
        @info "create new TEST DB"
        isfile("../test/test.db") && rm("../test/test.db")
        db = SQLite.DB("../test/test.db")
    elseif isfile(dbpath)
        return SQLite.DB(dbpath)
    else
        @info "create new empty DB"
        db = SQLite.DB(dbpath)
    end

    sql = read("../setup/create.sql", String)
    sql = replace(sql, "\n" => "")
    stmts = split(sql, ";"; keepempty=false)
    foreach(stmts) do stmt
        DBInterface.execute(db, stmt)
    end

    return db
end

const db = initdb()


## CRUD operations

"""
    create_dataset(ds::DataSet) -> Nothing

Create a new DataSet.
"""
function create_dataset(ds::DataSet)
    path = joinpath(config["storage_dir"], "tmp", string(ds.id))
    try
        mkpath(path)
    catch e
        showerror(stderr, e)
        throw(ErrorException("failed to create tmp directory for \"$(ds.id)\""))
    end

    try
        stmt_ds = SQLite.Stmt(db, "INSERT INTO dataset (id, label, stage, timestamp_created, timestamp_stagechange, retention, hidden, protected, public, downloads) VALUES (?,?,?,?,?,?,?,?,?,?);")
        stmt_f = SQLite.Stmt(db, "INSERT INTO file (dsid, fid, name, directory, size, type, chunks_total, chunks_received, timestamp_created, timestamp_uploaded) VALUES (?,?,?,?,?,?,?,?,?,?);")
        DBInterface.execute(stmt_ds, (string(ds.id), ds.label, string(ds.stage), string(ds.timestamp_created), string(ds.timestamp_stagechange), ds.retention, ds.hidden, ds.protected, ds.public, ds.downloads))
        fid = 1
        foreach(ds.files) do f
            DBInterface.execute(stmt_f, (string(ds.id), fid, f.name, f.directory, f.size, string(f.type), f.chunks_total, f.chunks_received, string(f.timestamp_created), missing))
            fid += 1
        end
    catch error
        @error "failed to store dataset: $(ds.id) to DB, during creation process"
        showerror(stderr, error)
    end

    return nothing
end


"""
    create_file_chunk(ds::DataSet, fid::Int, chunk::Int, blob::AbstractArray)

Add a data chunk of a file, to the storage layer.
"""
function create_file_chunk(ds::DataSet, fid::Int, chunk::Int, blob::AbstractArray)
    path = joinpath(config["storage_dir"], "tmp", string(ds.id), ds.files[fid].directory, ds.files[fid].name)
    if chunk > 1 && !ispath(path)
        @error "File missing: $path, can't store new chunk"
        throw(DomainError(path, "file missing"))
    elseif chunk == 1
        mkpath(dirname(path))
        open(path,"w") do file
            write(file, blob)
        end
    else
        open(path, "a") do file
            write(file, blob)
        end
    end

    return nothing
end


"""
    read_dataset(id::UUID)::Union{DataSet,Nothing}

Return DataSet with given ID or nothing, if the ID was not found.
"""
function read_dataset(id::UUID)::Union{DataSet,Nothing}
    local ds = nothing
    try
        stmt = SQLite.Stmt(db, "SELECT d.label, d.stage, d.timestamp_created, d.timestamp_stagechange, d.retention, d.hidden, d.protected, d.public, d.downloads, f.fid, f.name, f.directory, f.size, f.type, f.chunks_total, f.chunks_received, f.timestamp_created AS timestamp_created_f, f.timestamp_uploaded FROM dataset d JOIN file f ON d.id = f.dsid WHERE id = ?;")
        rs = DBInterface.execute(stmt, (string(id),))

        if isempty(rs)
            return nothing
        end

        files = []
        for r in rs
            if isnothing(ds)
                ds = DataSet(id, r.label, [], stage(r.stage), DateTime(r.timestamp_created), DateTime(r.timestamp_stagechange), r.retention, r.hidden, r.protected, r.public, [], r.downloads)
            end
            push!(files, File(r.name, r.directory, r.size, MIME(r.type), r.chunks_total, r.chunks_received, DateTime(r.timestamp_created_f), ismissing(r.timestamp_uploaded) ? nothing : DateTime(r.timestamp_uploaded)))
        end

        ds.files = files
    catch error
        @error "failed to retrieve dataset: $(string(id))"
        showerror(stderr, error)
    end

    return ds
end


"""
    read_datasets(; stages::Vector{Stage} = Vector{Stage}(), hidden::Union{Nothing,Bool} = nothing, public::Union{Nothing,Bool} = nothing)::Vector{DataSet}

Return a Vector of all DataSets or an empty Vector if there are no DataSets.
"""
function read_datasets(; stages::Vector{Stage} = Vector{Stage}(), hidden::Union{Nothing,Bool} = nothing, public::Union{Nothing,Bool} = nothing)::Vector{DataSet}
    # build query
    query= "SELECT id, label, stage, d.timestamp_created, d.timestamp_stagechange, retention, hidden, protected, public, downloads, fid, name, directory, size, type, chunks_total, chunks_received, f.timestamp_created AS timestamp_created_f, f.timestamp_uploaded FROM  dataset d join file f on d.id = f.dsid"
    stages_criteria = isempty(stages) ? nothing : "stage in $(sql_tuple(stages))"
    hidden_criteria = isnothing(hidden) ? nothing : "hidden = $hidden"
    public_criteria = isnothing(public) ? nothing : "public = $public"
    query = string(
        query,
        sql_where_clause(stages_criteria, hidden_criteria, public_criteria),
        " ORDER BY label;"
    )

    # execute query
    try
        rs = DBInterface.execute(db, query)
        return rs_to_datasets(rs)
    catch error
        @error "failed to retrieve datasets"
        showerror(stderr, error)
    end
end


"""
    read_datasets(pagesize::Int, page::Int; stages::Vector{Stage} = Vector{Stage}(), hidden::Union{Nothing,Bool} = nothing, public::Union{Nothing,Bool} = nothing)::Vector{DataSet}

Return a Vector of all DataSets of a specific page and a given pagesize or an empty Vector
if there are no DataSets.
For pagesize and page, positive values are expected, otherways an ErrorException is thrown.
"""
function read_datasets(pagesize::Int, page::Int; stages::Vector{Stage} = Vector{Stage}(), hidden::Union{Nothing,Bool} = nothing, public::Union{Nothing,Bool} = nothing)::Vector{DataSet}
    if pagesize <= 0 || page <= 0
        @warn "invalid pagesize: $pagesize or page: $page parameters"
        return Vector{DataSet}()
    end

    # build query
    query= "SELECT id, label, stage, d.timestamp_created, d.timestamp_stagechange, retention, hidden, protected, public, downloads, fid, name, directory, size, type, chunks_total, chunks_received, f.timestamp_created AS timestamp_created_f, f.timestamp_uploaded FROM  dataset d join file f on d.id = f.dsid WHERE f.dsid in (SELECT id FROM dataset LIMIT ? OFFSET ?)"
    stages_criteria = isempty(stages) ? nothing : "stage in $(sql_tuple(stages))"
    hidden_criteria = isnothing(hidden) ? nothing : "hidden = $hidden"
    public_criteria = isnothing(public) ? nothing : "public = $public"
    query = string(
        query,
        sql_where_clause(stages_criteria, hidden_criteria, public_criteria),
        " ORDER BY label;"
    )

    # execute query
    try
        stmt = SQLite.Stmt(db, query)
        rs = DBInterface.execute(stmt, (pagesize, (page-1)*pagesize))
        return rs_to_datasets(rs)
    catch error
        @error "failed to retrieve datasets of page: $page, with pagesize: $pagesize"
        showerror(stderr, error)
    end
end


"""
    sql_where_clause(criteria::Union{Nothing, AbstractString}...)

Returns a SQL where clause of the given criterias, ignoring empty or nothing arguments and
concatinating all criterias with logic AND.
"""
function sql_where_clause(criteria::Union{Nothing, AbstractString}...)
    c = filter(x -> !isnothing(x) && !isempty(x), criteria)

    if isempty(c)
        return ""
    end

    string(" WHERE ", join(c, " AND "))
end


"""
    sqltuple(iter) -> String

Returns a string which can be used in a SQL Query as a tuple, e.g ("foo", "bar").
"""
function sql_tuple(iter)
    str = map(x -> "\"" *  string(x) * "\"", iter)
    "(" * join(str, ", ") * ")"
end


"""
    rs_to_datasets(rs) -> Vector{DataSet}

Transforms a SQLite ResultSet into a vector of datasets.
"""
function rs_to_datasets(rs)
    datasets = Vector{DataSet}()
    ds = nothing
    files = Vector{File}()

    if isempty(rs)
        return datasets
    end

    for r in rs
        if isnothing(ds)    # no dataset processed yet
            ds = DataSet(UUID(r.id), r.label, [], stage(r.stage), DateTime(r.timestamp_created), DateTime(r.timestamp_stagechange), r.retention, r.hidden, r.protected, r.public, [], r.downloads)
        elseif string(ds.id) != r.id    # move on to processing next dataset
            ds.files = deepcopy(files)
            push!(datasets, ds)
            empty!(files)
            ds = DataSet(UUID(r.id), r.label, [], stage(r.stage), DateTime(r.timestamp_created), DateTime(r.timestamp_stagechange), r.retention, r.hidden, r.protected, r.public, [], r.downloads)
        end
        push!(files, File(r.name, r.directory, r.size, MIME(r.type), r.chunks_total, r.chunks_received, DateTime(r.timestamp_created_f), ismissing(r.timestamp_uploaded) ? nothing : DateTime(r.timestamp_uploaded)))
    end
    
    if !isnothing(ds)   # push last processed dataset
        ds.files = files
        push!(datasets, ds)
    end

    return datasets
end


"""
    read_dataset_metrics() -> DataFrame

Returns some metrics, grouped by stage and public availability about the stored datasets:
    * number of datasets
    * number of files
    * used storage
"""
function read_dataset_metrics()
    local df
    try
        df = DBInterface.execute(db, "SELECT stage, public, count(DISTINCT id) AS datasets, count(*) AS files, sum(size) AS used_storage FROM dataset d join file f on d.id = f.dsid GROUP BY stage, public;") |> DataFrame
        df.stage = stage.(df.stage)
        df.public = map(x -> x == 0 ? false : true, df.public)
    catch error
        @error "failed to retrieve datasets"
        showerror(stderr, error)
    end

    return df
end


"""
    read_dataset_stage(id::UUID) -> Union{Nothing,Stage}

returns the stage of the dataset corresponding to the given ID or nothing, if no dataset
with the given ID exists.
"""
function read_dataset_stage(id::UUID)
    try
        stmt = SQLite.Stmt(db, "SELECT stage FROM dataset WHERE id = ?;")
        rs = DBInterface.execute(stmt, (string(id),))

        if isempty(rs)
            return nothing
        end

        return (first(rs)).stage |> stage

        #@infiltrate
    catch error
        @error "faild to read stage from dataset: $id"
        showerror(stderr, error)
    end

    return nothing
end


"""
    update_file_chunks_received(ds::DataSet, fid::Int, chunks_received::Int)

Sets the chunks_received counter of the given file and dataset.
"""
function update_file_chunks_received(ds::DataSet, fid::Int, chunks_received::Int)
    try
        stmt = SQLite.Stmt(db, "UPDATE file SET chunks_received = ? WHERE dsid = ? AND fid = ?;")
        DBInterface.execute(stmt, (chunks_received, string(ds.id), fid))
    catch error
        @error "failed to set chunks received counter in dataset: $(ds.id) and file $fid"
        showerror(stderr, error)
    end

    return nothing
end


"""
    update_file_chunks_received(ds::DataSet, fid::Int, chunks_received::Int, timestamp_uploaded::Date)

Sets the chunks_received counter and upload timestamp of the given file and dataset.
"""
function update_file_chunks_received(ds::DataSet, fid::Int, chunks_received::Int, timestamp_uploaded::DateTime)
    try
        stmt = SQLite.Stmt(db, "UPDATE file SET chunks_received = ?, timestamp_uploaded = ?  WHERE dsid = ? AND fid = ?;")
        DBInterface.execute(stmt, (chunks_received, string(timestamp_uploaded), string(ds.id), fid))
    catch error
        @error "failed to set chunks received counter in dataset: $(ds.id) and file $fid"
        showerror(stderr, error)
    end

    return nothing
end


"""
    update_dataset_stage(id::UUID, stage::Stage)

Set the stage of a dataset to the given stage value.
"""
function update_dataset_stage(id::UUID, stage::Stage)
    try
        stmt = SQLite.Stmt(db, "UPDATE dataset SET stage = ?, timestamp_stagechange = ?  WHERE id = ?;")
        DBInterface.execute(stmt, (string(stage), string(now()), string(id)))
    catch error
        @error "failed to set stage in dataset: $id to $stage"
        showerror(stderr, error)
    end

    return nothing
end



"""
    update_dataset_promote(id::UUID)

Promote dataset from "tmp" to "live" storage layer, to make it available for download.
The dataset stage will be set to :available.
"""
function update_dataset_promote(id::UUID)
    @info "promote dataset: $id"
    tmppath = joinpath(config["storage_dir"], "tmp", string(id))
    ds = read_dataset(id)
    if !isdir(tmppath)
        @error "failed to promote dataset: $id, directory not found in \"tmp\" storage"
        return nothing
    elseif isnothing(ds)
        @error "failed to promote dataset: $id, no dataset found with that ID."
        return nothing
    end

    livepath = joinpath(config["storage_dir"], "live", string(id))
    mkpath(livepath)

    if length(ds.files) == 1 && ds.files[1].directory == "" # check if single file and not a within a directory
        try
            @info "$id: move file to 'live' directory"
            mv(joinpath(tmppath, ds.files[1].name), joinpath(livepath, ds.files[1].name))
        catch e
            showerror(stderr, e)
            @warn "$id: failed to move file to 'live' directory"
        end
    else
        label = replace(ds.label, "/" => "-")
        try
            @info "$id: create archive for uploaded files"
            run(Cmd(`zip -0 -q $(label).zip $(map(file -> joinpath(file.directory, file.name), ds.files))`, dir=tmppath))
            @info "$id: move archive to 'live' directory"
            mv(joinpath(tmppath, "$(label).zip"), joinpath(livepath, "$(label).zip"))
        catch e
            showerror(stderr, e)
            @warn "$id: failed to archive and move files to 'live' directory"
        end
    end
    @info "$id: DataSet moved to 'live' directory, successfully"
    
    try
        rm(tmppath, recursive=true)
    catch e
        @warn "failed to remove data from \"tmp\" storage layer"
        showerror(stderr, e)
    end
    
    update_dataset_stage(id, available)
    return nothing
end


"""
    update_dataset_downloads(id::UUID)

Sets the downloads counter of a given dataset, to the given value.
"""
function update_dataset_downloads(id::UUID, downloads::Int)
    try
        stmt = SQLite.Stmt(db, "UPDATE dataset SET downloads = ? WHERE id = ?;")
        DBInterface.execute(stmt, (string(downloads), string(id)))
    catch error
        @error "failed to set downloads counter in dataset: $id to $downloads"
        showerror(stderr, error)
    end

    return nothing
end


"""
    delete_dataset_hard(id::UUID)

Hard delete the given dataset, with all its files from storage and DB.
"""
function delete_dataset_hard(id::UUID)
    tmppath = joinpath(config["storage_dir"], "tmp", string(id))
    rm(tmppath, force=true, recursive=true)

    livepath = joinpath(config["storage_dir"], "live", string(id))
    rm(livepath, force=true, recursive=true)

    try
        stmt_f = SQLite.Stmt(db, "DELETE FROM file WHERE dsid = ?;")
        stmt_ds = SQLite.Stmt(db, "DELETE FROM dataset WHERE id = ?;")
        DBInterface.execute(stmt_f, (string(id),))
        DBInterface.execute(stmt_ds, (string(id),))
    catch error
        @error "failed to delete dataset: $id"
        showerror(stderr, error)
    end

    return nothing
end


"""
    delete_dataset_soft(id:UUID)

Soft delete of the given dataset.
"""
function delete_dataset_soft(id::UUID)
    update_dataset_stage(id, deleted)
end


"""
    checkds(ds::DataSet)

Check the consistency of a given Data Set.

Currently not in use ... 
"""
function checkds(ds::DataSet)
    tmppath = joinpath(config["storage_dir"], "tmp", string(ds.id))
    livepath = joinpath(config["storage_dir"], "live", string(ds.id))

    if ds.stage == available
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
    checkstorage()

Checking the storage layers for inconsistencies and performaing cleanup operations
on storage and DB level.
"""
function checkstorage()
    tmppath = joinpath(config["storage_dir"], "tmp")
    livepath = joinpath(config["storage_dir"], "live")

    foreach(UUID.(readdir(tmppath))) do id
        ds = read_dataset(id)
        if !isnothing(ds)
            if ds.stage == available
                @warn "$(ds.label) - $(ds.stage): inconsistent DB record found"
                delete_dataset_hard(id)
            end
        else
            @warn "$id: orphaned data set found"
            delete_dataset_hard(id)
        end
    end

    foreach(UUID.(readdir(livepath))) do id
        ds = read_dataset(UUID(id))
        if !isnothing(ds)
            if ds.stage == initial
                @warn "$(ds.label) - $(ds.stage): inconsistend DB record found"
                delete_dataset_hard(id)
            end
        else
            @warn "$id: orphaned data set found"
            delete_dataset_hard(id)
        end
    end

    DBInterface.execute(db, "VACUUM;")
end