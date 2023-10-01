import Base.isequal
import JSON.Writer

"""
A DataSet moves through different stages during its lifecycle:

        1. initial: upload and preprocessing
        2. scanned: malware scan completed with no findings
        3. available: DataSet can be downloaded
        4. deleted: After retention time the DataSet will be marked as deleted
"""
@enum Stage begin
    initial
    scanned
    available
    deleted
end

"""
    stage(str::AbstractString)

Return the stage enum corresponding to the given string representation.
"""
function stage(str::AbstractString)
    if str == "initial"
        Stage(0)
    elseif str == "scanned"
        Stage(1)
    elseif str == "available"
        Stage(2)
    elseif str == "deleted"
        Stage(3)
    else
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
    filenames::Vector{String}
    stage::Stage
    stagechange::DateTime
    timestamp::DateTime
    retention::Int
    hidden::Bool
    protected::Bool
    public::Bool
    types::Vector{MIME}
    sizes::Vector{Int}
    downloads::Int
end

DataSet(id, label, tags, filenames, retention, hidden, public, types, sizes) = DataSet(id, label, tags, filenames, initial, now(), now(), retention, hidden, false, public, types, sizes, 0)

function isequal(x::DataSet, y::DataSet)
    x.id == y.id &&
    x.filenames == y.filenames &&
    x.label == y.label &&
    x.tags == y.tags &&
    x.stage == y.stage &&
    x.stagechange == y.stagechange &&
    x.timestamp == y.timestamp &&
    x.retention == y.retention &&
    x.hidden == y.hidden &&
    x.protected == y.protected &&
    x.public == y.public &&
    x.types == y.types &&
    x.sizes == y.sizes &&
    x.downloads == y.downloads
end

function dataset(dict::Dict)::DataSet
    DataSet(
        UUID(dict["id"]),
        dict["label"],
        dict["tags"],
        dict["filenames"],
        stage(dict["stage"]),
        DateTime(dict["stagechange"]),
        DateTime(dict["timestamp"]),
        dict["retention"],
        dict["hidden"],
        dict["protected"],
        dict["public"],
        MIME.(dict["types"]),
        dict["sizes"],
        dict["downloads"]
    )
end

function unmarshal_dataset(dict::Dict)::Dict{UUID, DataSet}
    datasets = Dict{UUID, DataSet}()

    foreach(values(dict)) do element
        ds = dataset(element)
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