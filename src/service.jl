"""
    add_dataset(id::UUID, filename::Vector{AbstractString}, type::Vector{MIME}, files)

Add a new Data Set
"""
function add_dataset(id::UUID, label::String, filename::Vector{String}, type::Vector{T} where T <: MIME, size::Vector{Int}, iobuffers)
    ds = DataSet(id=id, label=label, filename=filename, type=type, size=size)

    create_dataset(ds, iobuffers)
end


"""
    process_dataset(id::UUID)

Process a newly uploaded dataset.
"""
function process_dataset(id::UUID)
    @warn "malware check (not implemented yet, this is just mocked)"
    ds = read_dataset(id)
    # mock malware check
    sleep(10)
    ds.stage = scanned
    update_dataset(ds)

    @info "check DataSet consistency (not implemented yet)"
    # availability of all files in expected size and type

    @info "optimize storage (not implemented yet)"
    
    @info "prepare for download"
    promote_dataset(id)
end