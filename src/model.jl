import Base.isequal


"""
    A file within a DataSet
"""
mutable struct File
    name::String
    directory::String
    size::Int
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


function isequal(x::File, y::File)
    x.name == y.name &&
    x.directory == y.directory &&
    x.size == y.size &&
    x.type == y.type
end


"""
A DataSet moves through different states during its lifecycle:

        * initial: A newly created DataSet
        * uploaded: All files of the initial DataSet were uploaded
        * scanned: Malware scan completed successfully with no findings
        * prepared: DataSet preprocessing completed successfully
        * available: DataSet is available for downloaded
        * changing: DataSet is currently being changed, after it was available
        * deleted: After retention time the DataSet will be marked as deleted
"""
@enum State begin
    initial
    uploaded
    scanned
    prepared
    available
    changing
    deleted
end

"""
    state(str::AbstractString) -> State

Return the state enum corresponding to the given string representation.
"""
function state(str::AbstractString)
    try
        getproperty(Mercury, Symbol(str))
    catch _
        throw(ErrorException("invalid state: $str"))
    end
end

"""
    A DataSet is a logic representation of one or more files of random type.
"""
mutable struct DataSet
    id::UUID
    label::String
    tags::Vector{String}
    state::State
    timestamp_created::DateTime
    timestamp_stagechange::DateTime
    retention::Int
    hidden::Bool
    protected::Bool
    public::Bool
    files::Vector{File}
    downloads::Int
end

DataSet(id, label, tags, retention, hidden, public, files) = DataSet(id, label, tags, initial, now(), now(), retention, hidden, false, public, files, 0)


function isequal(x::DataSet, y::DataSet)
    x.id == y.id &&
    x.label == y.label &&
    x.tags == y.tags &&
    x.hidden == y.hidden &&
    x.protected == y.protected &&
    x.public == y.public &&
    isequal(x.files, y.files)
end


"""
SystemStatus represents the status Mercury at a given point in time.

Some metrics are restricted and might be set to nothing.
"""
struct StorageStatus
    count_ds::Int
    count_files::Int
    used_storage::Union{String,Nothing}
    available_storage::Union{String,Nothing}
    total_storage::Union{String,Nothing}
    used_relative::Union{String,Nothing}
end

StorageStatus(count_ds, count_files) = StorageStatus(count_ds, count_files, nothing, nothing, nothing, nothing)


"""
UploadProgress represents the progress of an upload process at one point in time.
"""
struct UploadProgress
    ds_progress::Int
    ds_completed::Bool
    file_progress::Int
    file_name::String
    file_id::Int
    file_completed::Bool
    next_file_id::Union{Int,Nothing}
    next_chunk_id::Union{Int,Nothing}
end