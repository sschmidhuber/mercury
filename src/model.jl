import Base.isequal
import JSON.Writer


"""
    A file within a DataSet
"""
mutable struct File
    name::String
    directory::String
    size::Int   # file size in bytes
    type::MIME
    chunks_total::Int
    chunks_received::Int
    timestamp_created::DateTime
    timestamp_uploaded::Union{DateTime, Nothing}
end

File(name, directory, size, type) = begin
    # calculate number of chunks
    chunk_size = config["network"]["chunk_size"]
    chunks_full = size / chunk_size |> floor |> Int
    chunks_total = size % chunk_size == 0 ? chunks_full : chunks_full += 1

    File(name, directory, size, type, chunks_total, 0, now(), nothing)
end

File(dict::Dict) = begin
    File(
        dict["name"],
        dict["directory"],
        dict["size"],
        MIME(dict["type"]),
        dict["chunks_total"],
        dict["chunks_received"],
        DateTime(dict["timestamp_created"]),
        dict["timestamp_uploaded"] |> isnothing ? nothing : DateTime(dict["timestamp_uploaded"])
        )
end


function isequal(x::File, y::File)
    x.name == y.name &&
    x.directory == y.directory &&
    x.size == y.size &&
    x.type == y.type
end


"""
A DataSet moves through different stages during its lifecycle:

        1. initial: dataset created
        2. scanned: malware scan completed with no findings
        3. prepared: DataSet preprocessing completed successfully
        4. available: DataSet can be downloaded
        5. deleted: After retention time the DataSet will be marked as deleted
"""
@enum Stage begin
    initial
    scanned
    prepared
    available
    deleted
end

"""
    stage(str::AbstractString)::Stage

Return the stage enum corresponding to the given string representation.
"""
function stage(str::AbstractString)::Stage
    try
            getproperty(Mercury, Symbol(str))
    catch _
        @error "invalid stage: $str"
        throw(DomainError(str))
    end
end

"""
    A DataSet is a logic representation of one or more files of random type.
"""
mutable struct DataSet
    id::UUID
    label::String
    tags::Vector{String}
    stage::Stage
    stagechange::DateTime
    timestamp::DateTime
    retention::Int
    hidden::Bool
    protected::Bool
    public::Bool
    files::Vector{File}
    downloads::Int
end

DataSet(id, label, tags, retention, hidden, public, files) = DataSet(id, label, tags, initial, now(), now(), retention, hidden, false, public, files, 0)

DataSet(dict::Dict) = begin
    DataSet(
        UUID(dict["id"]),
        dict["label"],
        dict["tags"],
        stage(dict["stage"]),
        DateTime(dict["stagechange"]),
        DateTime(dict["timestamp"]),
        dict["retention"],
        dict["hidden"],
        dict["protected"],
        dict["public"],
        File.(dict["files"]),
        dict["downloads"]
    )
end


function isequal(x::DataSet, y::DataSet)
    x.id == y.id &&
    x.label == y.label &&
    x.tags == y.tags &&
    x.hidden == y.hidden &&
    x.protected == y.protected &&
    x.public == y.public &&
    isequal(x.files, y.files)
end


function unmarshal_dataset(dict::Dict)::Dict{UUID, DataSet}
    datasets = Dict{UUID, DataSet}()

    foreach(values(dict)) do element
        ds = DataSet(element)
        datasets[ds.id] = ds
    end

    return datasets
end


function JSON.Writer.lower(x::MIME)
    x |> string
end


function JSON.Writer.lower(x::UUID)
    x |> string
end