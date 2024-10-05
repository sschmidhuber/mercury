## router

restricted = router("", tags=["Restricted"], middleware=[internal])
rest = router("/rest", tags=["REST API"])


## top level navigation

@get "/" function()
    redirect("index.html")
end

@get "/index.html" function(req)
    status = storage_status(req.context[:internal])
    available_ds = available_datasets(req.context[:internal])
    render_datasets_page(status, available_ds, req.context[:internal])
end

@get "/upload.html" function(req)
    render_upload_page(req.context[:internal])
end


## API endpoints

@get "/health" function()
    healthcheck()
end


@get "/storage-status" function(req)
    storage_status(req.context[:internal])
end

@get rest("/storage-status") function(req)
    status = storage_status(req.context[:internal])
    render_storage_status(status)
end


@get "/config" function(req)
    clientconfig(req.context[:internal])
end


## Create a new DataSet REST API

@post rest("/datasets") function (req, middleware=[internal])
    local request_body
    try
        request_body = formdata(req)
    catch e
        showerror(stderr, e)
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "failed to parse Formdata request body") |> JSON.json)
    end

    @show request_body

    render_alert("Not implemented, yet!", "primary")

    #return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "failed to parse Formdata request body") |> JSON.json)
end

## Create a new DataSet Data API
#= inactive until needed
@post "/datasets" function(req, middleware=[internal])
    local request_body
    try
        request_body = Oxygen.json(req)
        @show request_body
    catch e
        showerror(stderr, e)
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "failed to parse JSON request body") |> JSON.json)
    end
    
    
    # create files
    files = Vector{File}()
    foreach(request_body.files) do file
        try
            mime = mime_from_path(file.path) |> isnothing ? MIME(file.type) : mime_from_path(file.path)
            file = File(basename(file.path), dirname(file.path), file.size, mime)
            
            # file validations
            if file.size > config["limits"]["filesize"]
                return HTTP.Response(422, Dict("error" => "file size exceeds limit", "detail" => "file size exceeds limit of $(config["limits"]["filesize"] |> format_size)") |> JSON.json)
            end

            if isnothing(file.name) || isempty(file.name) || contains(file.name, '/')
                HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "file name missing") |> JSON.json)
            end

            if Sys.iswindows()
                if ['/', '<', '>', '\\', ':', '"', '|', '?', '*'] .∈ file.name |> sum != 0
                    HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "file name contains character not allowed on Windows systems") |> JSON.json)
                end
                if ['<', '>', ':', '"', '|', '?', '*'] .∈ file.directory |> sum != 0
                    HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "directory name contains character not allowed on Windows systems") |> JSON.json)
                end
            else
                if '/' ∈ file.name
                    HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "file name contains not allowed character '/'") |> JSON.json)
                end
            end
            push!(files, file)
        catch err
            @warn "couldn't create file"
            showerror(stderr, err)

            return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "failed to create file") |> JSON.json)
        end
    end


    # create DataSet
    dsid = uuid4()

    if isnothing(request_body.label) || isempty(request_body.label)
        if length(request_body.files) == 1
            label = (request_body.files |> only).path |> basename
        else
            label = "Data Set $(today())"
        end
    else
        label = request_body.label
    end

    local retention_time
    try
        retention_time = parse(Int, request_body.retention_time)
    catch err
        @warn "couldn't parse \"retention_time\""
        showerror(stderr, err)
        retention_time = config["retention"]["default"]
    end

    local hidden
    try
        hidden = request_body.hidden
    catch err
        @warn "couldn't parse \"hidden\""
        showerror(stderr, err)
        hidden = false
    end

    local public
    try
        public = request_body.public
    catch err
        @warn "couldn't parse \"public\""
        showerror(stderr, err)
        public = false
    end


    # dataset validations
    if retention_time < config["retention"]["min"] || retention_time > config["retention"]["max"]
        return HTTP.Response(400, Dict("error" => "invalid request", "detail" => "retention time: $retention_time, out of bounds ($(config["retenion"]["min"])-$(config["retention"]["max"]))") |> JSON.json)
    end

    if length(files) > config["limits"]["filenumber_per_dataset"]
        return HTTP.Response(413, Dict("error" => "dataset exceeds max file number", "detail" => "dataset exceeds max file number of $(config["limits"]["filenumber_per_dataset"])") |> JSON.json)
    end

    if count_ds() >= config["limits"]["datasetnumber"]
        return HTTP.Response(507, Dict("error" => "maximum number of datasets exceeded", "detail" => "limit of $(config["limits"]["datasetnumber"]) datasets exceeded") |> JSON.json)
    end

    total_size = map(x -> x.size, files) |> sum
    if total_size > config["limits"]["datasetsize"]
        return HTTP.Response(413, Dict("error" => "dataset exceeds size limit", "detail" => "dataset exceeds size limit of $(config["limits"]["datasetsize"] |> format_size)") |> JSON.json)
    end 
    if total_size > available_storage()
        return HTTP.Response(507, Dict("error" => "storage limit exceeded", "detail" => "storage limit of $(config["limits"]["storage"] |> format_size) exceeded") |> JSON.json)
    end


    ds = add_dataset(dsid, label, retention_time, hidden, public, files)
    return HTTP.Response(201, ds |> JSON.json)
end=#


## Create a new file in an existing DataSet
@post "/datasets/{id}/files" function(req, id)
    return HTTP.Response(501, Dict("error" => "not implemented, yet", "detail" => "Adding files to existing DataSets is currently not implemented.") |> JSON.json)
end


## Upload a chunk of data of an existing file of some DataSet
@put "/datasets/{dsid}/files/{fid}/{chunk}" function(req, dsid, fid, chunk)
    local progress
    try
        content = HTTP.parse_multipart_form(req)
        if content |> isnothing
            return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "parsing multipart form failed") |> JSON.json)
        end
        
        blob = (content |> only).data.data
        progress = add_chunk(UUID(dsid), parse(Int, fid), parse(Int, chunk), blob)
    catch err
        if err isa DomainError
            return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "failed to process chunk") |> JSON.json)
        else
            @warn "couldn't process chunk $chunk of file: $fid of dataset: $dsid"
            showerror(stderr, err)

            return HTTP.Response(500, Dict("error" => "internal server error", "detail" => "failed to process chunk") |> JSON.json)
        end
    end
    
    return HTTP.Response(200, progress |> JSON.json)
end



@get "/datasets" function(req)
    available_ds = available_datasets(req.context[:internal])
end


@get "/datasets/{id}" function(req, id)
    local dsid
    try
        dsid = UUID(id)
    catch
        sleep(5)
        return HTTP.Response(422, Dict("error" => "invalid request", "detail" => "$id is not a valid UUID") |> JSON.json)
    end

    # check availability
    ds::DataSet = load_dataset(dsid)
    if isnothing(ds) || ds.stage != available
        sleep(5)
        return HTTP.Response(404, Dict("error" => "resource not found", "detail" => "there is no data set available with ID: $id") |> JSON.json)
    end

    # check authorization
    if !ds.public && !req.context[:internal]
        sleep(5)
        return HTTP.Response(403, Dict("error" => "access denied", "detail" => "access to this data set is restricted") |> JSON.json)
    end

    uri = download_uri(ds)
    download_name = download_filename(ds)
    ds.downloads += 1
    update_dataset(ds)

    return HTTP.Response(200, ["X-Accel-Redirect" => uri, "Content-Disposition" => "attachment; filename=\"$download_name\""])
end


@get "/datasets/{id}/properties" function(req, id::String)
    try
        dsid = UUID(id)
    catch
        sleep(5)
        return HTTP.Response(422, Dict("error" => "invalid request", "detail" => "$id is not a valid UUID") |> JSON.json)
    end

    res = properties(UUID(id))

    # check availability
    if isnothing(res)
        sleep(5)
        return HTTP.Response(404, Dict("error" => "no DataSet with ID: $id found") |> JSON.json)
    end

    # check authorization
    if !res["public"] && !req.context[:internal]
        sleep(5)
        return HTTP.Response(403, Dict("error" => "access denied", "detail" => "access to this data set is restricted") |> JSON.json)
    end

    return res
end