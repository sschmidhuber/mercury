@enum Stage begin
    initial
    available
    deleted
end

Base.@kwdef mutable struct Dataset
    id::UUID
    filename::String
    stage::Stage = initial
    timestamp::DateTime = now()
    retention::Period = Day(3)
    hidden::Bool = false
    protected::Bool = false
    encrypted::Bool = false
    type::MIME
    size::Int
end