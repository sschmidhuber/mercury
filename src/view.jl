
function render_initial_page(storage_status::StorageStatus, internal=false)
    storage_status_tpl = Mustache.load("templates/storage-status.html")
    storage_status_html = Mustache.render(storage_status_tpl, storage_status)

    index_tpl = Mustache.load("templates/index.html")
    Mustache.render(index_tpl, storage_status=storage_status_html)
end

"""
    render_storage_status(storage_status::StorageStatus, internal=false)

"""
function render_storage_status(storage_status::StorageStatus, internal=false)
    tpl = Mustache.load("templates/storage-status.html")
    Mustache.render(tpl, storage_status)
end