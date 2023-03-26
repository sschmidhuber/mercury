"""
    add_dataset(id::UUID, filename::Vector{AbstractString}, type::Vector{MIME}, files)

Add a new Data Set
"""
function add_dataset(id::UUID, label::String, filename::Vector{String}, type::Vector{T} where T <: MIME, size::Vector{Int}, iobuffers)
    ds = DataSet(id=id, label=label, filename=filename, type=type, size=size)

    create_dataset(ds, iobuffers)
end