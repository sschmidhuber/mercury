import JSON.Writer


@enum Stage begin
    initial
    available
    deleted
end

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


Base.@kwdef mutable struct DataSet
    id::UUID
    filename::String
    stage::Stage = initial
    timestamp::DateTime = now()
    retention::Int = config["retention"]["default"]
    hidden::Bool = false
    protected::Bool = false
    type::MIME
    size::Int
end

function dataset(dict::Dict)
    DataSet(
        UUID(dict["id"]),
        dict["filename"],
        stage(dict["stage"]),
        DateTime(dict["timestamp"]),
        dict["retention"],
        dict["hidden"],
        dict["protected"],
        MIME(dict["type"]),
        dict["size"]
    )
end

function dataset(array::Vector)
    datasets = Dict{UUID, DataSet}()

    foreach(array) do element
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