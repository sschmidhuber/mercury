#=
# Views
#
# A view holds a entity of the data model and adds additional fields for rendering in the UI.
#
=#

"""
    The DataSetView holds the corresponding DataSet and provides additional fields
    to be displayed in the UI.
"""
struct DataSetView
    ds::DataSet
    id_short::String
    size_total_f::String
    count_files_f::String
    time_left_f::String
    download_extension::String
    download_filename::String
    download_url::String
    email_body::String
end

function DataSetView(ds::DataSet)
    count_files_f = "$(length(ds.files)) $(length(ds.files) == 1 ? "file" : "files")"
    time_of_deletion = ds.timestamp_created + Hour(ds.retention)
    download_extension = length(ds.files) == 1 && ds.files[1].directory |> isempty ? extension_from_mime(ds.files[1].type) : ".zip"
    download_name = download_filename(ds)
    download_url = (ds.public ? config["network"]["external_url"] : config["network"]["internal_url"]) * "/datasets/$(ds.id)"
    email_body = "Download Link: $(download_url)$(ds.public ? "" : "\n\nThe data set is only available within the internal network.")" |> HTTP.escape

    DataSetView(
        ds,
        string(ds.id)[1:8] * "...",
        format_size(storage_size(ds)),
        count_files_f,
        format_retention(time_of_deletion),
        download_extension,
        download_name,
        download_url,
        email_body
    )
end


#=
# Render functions
=#

function render_progress_new_Dataset(ds::DataSet)
    tpl = Mustache.load("templates/progress_new_dataset.html")
    Mustache.render(tpl, dsid=ds.id, fid=1, chunk=1, filename=ds.files[1].name)
end


function render_progress_upload(ds::DataSet, progress::UploadProgress)
    tpl = Mustache.load("templates/progress_upload.html")

    # get the last 5 files which were uploaded already
    last_file_1 = progress.next_file_id > 1 ? ds.files[progress.next_file_id-1].name : nothing
    last_file_2 = progress.next_file_id > 2 ? ds.files[progress.next_file_id-2].name : nothing
    last_file_3 = progress.next_file_id > 3 ? ds.files[progress.next_file_id-3].name : nothing
    last_file_4 = progress.next_file_id > 4 ? ds.files[progress.next_file_id-4].name : nothing
    last_file_5 = progress.next_file_id > 5 ? ds.files[progress.next_file_id-5].name : nothing
    
    if progress.file_id != progress.next_file_id
        # just switched to new file
        progress_current_file = 0
    else
        progress_current_file = progress.file_progress
    end

    Mustache.render(
        tpl,
        dsid=ds.id,
        fid=progress.next_file_id,
        chunk=progress.next_chunk_id,
        filename=ds.files[progress.next_file_id].name,
        filename_short=shortstring(ds.files[progress.next_file_id].name, 17),
        progress_dataset=progress.ds_progress,
        progress_file=progress_current_file,
        last_file_1=last_file_1,
        last_file_2=last_file_2,
        last_file_3=last_file_3,
        last_file_4=last_file_4,
        last_file_5=last_file_5,
        last_file_1_short=shortstring(last_file_1, 17),
        last_file_2_short=shortstring(last_file_2, 17),
        last_file_3_short=shortstring(last_file_3, 17),
        last_file_4_short=shortstring(last_file_4, 17),
        last_file_5_short=shortstring(last_file_5, 17)
        )
end


function render_progress_upload_completed(ds::DataSet, progress::UploadProgress)
    tpl = Mustache.load("templates/progress_upload_completed.html")

    # get the last 5 files which were uploaded already
    last_file_1 = length(ds.files) > 1 ? ds.files[end-1].name : nothing
    last_file_2 = length(ds.files) > 2 ? ds.files[end-2].name : nothing
    last_file_3 = length(ds.files) > 3 ? ds.files[end-3].name : nothing
    last_file_4 = length(ds.files) > 4 ? ds.files[end-4].name : nothing
    last_file_5 = length(ds.files) > 5 ? ds.files[end-5].name : nothing
    
    Mustache.render(
        tpl,
        filename=progress.file_name,
        filename_short=shortstring(progress.file_name, 17),
        dsid=ds.id,
        last_file_1=last_file_1,
        last_file_2=last_file_2,
        last_file_3=last_file_3,
        last_file_4=last_file_4,
        last_file_5=last_file_5,
        last_file_1_short=shortstring(last_file_1, 17),
        last_file_2_short=shortstring(last_file_2, 17),
        last_file_3_short=shortstring(last_file_3, 17),
        last_file_4_short=shortstring(last_file_4, 17),
        last_file_5_short=shortstring(last_file_5, 17)
    )
end


function render_progress_data_processing(state::State, dsid::UUID)
    tbl = Mustache.load("templates/progress_data_processing.html")

    if state ∈ [initial, scanned, prepared]
        Mustache.render(tbl, color="bg-primary", text="in progress", polling=true, dsid=dsid)
    else
        Mustache.render(tbl, color="bg-danger", text="failed", polling=false)
    end
end


function render_progress_data_processing(ds::Union{DataSet,Nothing})
    tbl = Mustache.load("templates/progress_data_processing.html")

    if ds.state == available
        ds_html = render_datasets([ds])
        Mustache.render(tbl, color="bg-success", text="done", polling=false, dataset=ds_html)
    else
        Mustache.render(tbl, color="bg-danger", text="failed", polling=false)
    end
end


"""
    render_alert(message::String, alert_type::String="primary")

Supported alert_ypes are:
 * primary
 * secondary
 * success
 * danger
 * warning
 * info
 * light
 * dark
"""
function render_alert(message::String, alert_type::String="primary")
    tpl = mt"<div hx-swap-oob=\"true\" id=\"alert\" class=\"alert alert-{{:type}}\" role=\"alert\">{{:message}}</div>"
    Mustache.render(tpl, message=message, type=alert_type)
end


"""
    render_initial_page(storage_status::StorageStatus, datasets::Union{Vector{DataSet},Nothing}, internal=false)

"""
function render_datasets_page(storage_status::StorageStatus, datasets::Union{Vector{DataSet},Nothing}, internal=false)
    # load and render subsections
    storage_status_html = render_storage_status(storage_status, internal)
    ds_html = render_datasets(datasets, internal)

    @show internal
    external = internal ? "" : "visually-hidden"
    # join subsections together
    index_tpl = Mustache.load("templates/index.html")
    Mustache.render(index_tpl, storage_status=storage_status_html, ds=ds_html, external=external)
end

function render_upload_page(internal=false)
    upload_tpl = Mustache.load("templates/upload.html")
    Mustache.render(upload_tpl)
end

"""
    render_datasets(datasets::Union{Vector{DataSet},Nothing}, internal=false)

"""
function render_datasets(datasets::Union{Vector{DataSet},Nothing}, internal=false)
    if isnothing(datasets)
        ds_html = "no visible Datasets available"
    else
        ds_tpl = Mustache.load("templates/dataset.html")
        dataset_views = DataSetView.(datasets)
        ds_html = Mustache.render(ds_tpl, datasets=dataset_views)
    end

    return ds_html
end

"""
    render_storage_status(storage_status::StorageStatus, internal=false)

"""
function render_storage_status(storage_status::StorageStatus, internal=false)
    tpl = Mustache.load("templates/storage-status.html")
    Mustache.render(tpl, storage_status)
end