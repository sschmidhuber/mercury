@enum Stage begin
    initial
    available
    deleted
end

mutable struct Dataset
    id::UUID
    stage::Stage
    timestamp::DateTime
    retention::Period
    hidden::Bool
    protected::Bool
    encrypted::Bool
    type::MIME
    size::Int
end