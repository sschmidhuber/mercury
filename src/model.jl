import Base.isequal
import JSON.Writer

"""
A DataSet moves through different stages during its lifecycle:

        1. initial: upload and preprocessing
        2. available: DataSet can be downloaded
        3. deleted: After retention time the DataSet will be marked as deleted
"""
@enum Stage begin
    initial
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
    elseif str == "available"
        Stage(1)
    elseif str == "deleted"
        Stage(2)
    else
        throw(DomainError(str))
    end
end

"""
    A DataSet is a logic representation of one or more files of random type.
"""
Base.@kwdef mutable struct DataSet
    id::UUID
    label::String
    filename::Vector{String}
    stage::Stage = initial
    timestamp::DateTime = now()
    retention::Int = config["retention"]["default"]
    hidden::Bool = false
    protected::Bool = false
    type::Vector{MIME}
    size::Vector{Int}
end

function isequal(x::DataSet, y::DataSet)
    x.id == y.id &&
    x.filename == y.filename &&
    x.label == y.label &&
    x.stage == y.stage &&
    x.timestamp == y.timestamp &&
    x.retention == y.retention &&
    x.hidden == y.hidden &&
    x.protected == y.protected &&
    x.type == y.type &&
    x.size == y.size
end

function dataset(dict::Dict)
    DataSet(
        UUID(dict["id"]),
        dict["label"],
        dict["filename"],
        stage(dict["stage"]),
        DateTime.(dict["timestamp"]),
        dict["retention"],
        dict["hidden"],
        dict["protected"],
        MIME.(dict["type"]),
        dict["size"]
    )
end

function unmarshal_dataset(dict::Dict)
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