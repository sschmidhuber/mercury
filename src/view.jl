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
    time_of_deletion = ds.timestamp + Hour(ds.retention)
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