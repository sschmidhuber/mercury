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


# create a new Data Set
@post rest("/datasets") function (req, middleware=[internal])
    local request_body
    try
        request_body = formdata(req)
    catch e
        showerror(stderr, e)
        return HTTP.Response(422, render_alert("Failed to parse Formdata request body.", "danger"))
    end

    # create files
    files = Vector{File}()
    counter = 0
    while true
        if haskey(request_body, string(counter))
            try
                input = JSON3.read(request_body[string(counter)], NamedTuple)
                mime = mime_from_path(input.path) |> isnothing ? MIME(input.type) : mime_from_path(input.path)
                file = File(basename(input.path), dirname(input.path), input.size, mime)
                
                # file validations
                if file.size > config["limits"]["filesize"]
                    return HTTP.Response(422, render_alert("File size exceeds limit of $(config["limits"]["filesize"] |> format_size).", "danger"))
                end
    
                if isnothing(file.name) || isempty(file.name) || contains(file.name, '/')
                    return HTTP.Response(422, render_alert("File name missing.", "danger"))
                end
    
                if Sys.iswindows()
                    if ['/', '<', '>', '\\', ':', '"', '|', '?', '*'] .∈ file.name |> sum != 0
                        return HTTP.Response(422, render_alert("File name contains character not allowed on Windows systems.", "danger"))
                    end
                    if ['<', '>', ':', '"', '|', '?', '*'] .∈ file.directory |> sum != 0
                        return HTTP.Response(422, render_alert("Directory name contains character not allowed on Windows systems.", "danger"))
                    end
                else
                    if '/' ∈ file.name
                        return HTTP.Response(422, render_alert("File name contains not allowed character '/'.", "danger"))
                    end
                end
                push!(files, file)
            catch err
                @warn "couldn't create file"
                showerror(stderr, err)
    
                return HTTP.Response(422, render_alert("Failed to create file.", "danger"))
            end
        else
            # no further key found
            break
        end
        counter += 1
    end

    if counter == 0
        return HTTP.Response(422, render_alert("Please select at least one file to upload.", "warning"))
    end

    # create DataSet
    dsid = uuid4()

    if isnothing(request_body["label"]) || isempty(strip(request_body["label"]))
        if counter == 1
            label = (files |> only).name |> basename
        else
            label = "Data Set $(today())"
        end
    else
        label = request_body["label"]
    end

    local retention_time
    try
        retention_time = parse(Int, request_body["retentionTime"])
    catch err
        @warn "couldn't parse \"retention_time\""
        showerror(stderr, err)
        return HTTP.Response(422, render_alert("Couldn't parse retention time.", "danger"))
    end

    # checkbox values are only transmitted if true in HTML forms
    hidden = haskey(request_body, "hidden") ? true : false
    public = haskey(request_body, "public") ? true : false

    # dataset validations
    if retention_time < config["retention"]["min"] || retention_time > config["retention"]["max"]
        return HTTP.Response(400, render_alert("Retention time: $retention_time, out of bounds ($(config["retenion"]["min"])-$(config["retention"]["max"])).", "warning"))
    end

    if length(files) > config["limits"]["filenumber_per_dataset"]
        return HTTP.Response(413, render_alert("Data Set exceeds max file number of $(config["limits"]["filenumber_per_dataset"]).", "warning"))
    end

    if count_ds() >= config["limits"]["datasetnumber"]
        return HTTP.Response(507, render_alert("Limit of $(config["limits"]["datasetnumber"]) datasets exceeded.", "danger"))
    end

    total_size = map(x -> x.size, files) |> sum
    if total_size > config["limits"]["datasetsize"]
        return HTTP.Response(413, render_alert("Data Set exceeds size limit of $(config["limits"]["datasetsize"] |> format_size)", "danger"))
    end
    if total_size > available_storage()
        return HTTP.Response(507, render_alert("Storage limit of $(config["limits"]["storage"] |> format_size) exceeded.", "danger"))
    end

    local ds
    try
        ds = add_dataset(dsid, label, retention_time, hidden, public, files)
    catch err
        @error "couldn't add new data set: $dsid"
        showerror(stderr, err)
        return HTTP.Response(500, render_alert("Unexpected error, couldn't add new data set.", "danger"))
    end
    
    # return header with event, containing first expected data chunk
    uploaddata = Dict("uploadData" => (dsid = 1, fid = 1, chunk = 1))

    return HTTP.Response(201, ["HX-Trigger-After-Settle" => JSON3.write(uploaddata)], render_progress_new_Dataset(ds))
end


## Create a new DataSet (Data API)
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
    return HTTP.Response(501, Dict("error" => "not implemented, yet", "detail" => "Adding files to existing DataSets is currently not implemented.") |> JSON3.write)
end


## Upload a chunk of data of an existing file of some DataSet
@put rest("/datasets/{dsid}/files/{fid}/{chunk}") function(req, dsid, fid, chunk)
    local ds, progress
    try
        content = HTTP.parse_multipart_form(req)
        if content |> isnothing
            return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "parsing multipart form failed") |> JSON3.write)
        end
        blob = (content |> only).data.data
        ds = read_dataset(UUID(dsid))
        if ds |> isnothing
            return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "invalid DataSet ID: $dsid") |> JSON3.write)
        end
        progress = add_chunk!(ds, parse(Int, fid), parse(Int, chunk), blob)
    catch err
        if err isa DomainError
            return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "failed to process chunk") |> JSON3.write)
        else
            @warn "couldn't process chunk $chunk of file: $fid of dataset: $dsid"
            showerror(stderr, err)

            return HTTP.Response(500, Dict("error" => "internal server error", "detail" => "failed to process chunk") |> JSON3.write)
        end
    end

    if progress.ds_completed
        # return with HX-Trigger header to release wakelock
        return HTTP.Response(201, ["HX-Trigger" => "uploadCompleted"], render_progress_upload_completed(ds, progress))
    else
        # return HX-Trigger header with next expected data chunk
        uploaddata = Dict("uploadData" => (dsid = dsid, fid = progress.next_file_id, chunk = progress.next_chunk_id))
    
        return HTTP.Response(201, ["HX-Trigger-After-Settle" => JSON3.write(uploaddata)], render_progress_upload(ds, progress))
    end   
end


#= inactive until needed
@put "/datasets/{dsid}/files/{fid}/{chunk}" function(req, dsid, fid, chunk)
    local progress
    try
        content = HTTP.parse_multipart_form(req)
        if content |> isnothing
            return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "parsing multipart form failed") |> JSON.json)
        end
        
        blob = (content |> only).data.data
        progress = add_chunk!(UUID(dsid), parse(Int, fid), parse(Int, chunk), blob)
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
end=#


# requests the state of a Data Set (e.g. while created)
@get rest("/datasets/{id}/state") function(req, id::String)
    dsid = UUID(id)
    try
        state = read_dataset_stage(dsid)
        if state ∈ [initial, scanned, prepared]
            return render_progress_data_processing(state, dsid)
        else
            ds = read_dataset(dsid)
            return render_progress_data_processing(ds)
        end
    catch error
        showerror(stderr, error)
        sleep(5)
        return HTTP.Response(422, Dict("error" => "invalid request", "detail" => "$id is not a valid UUID") |> JSON3.write)
    end
end

# download a data set, this is not a REST call since download state in managed by the browser
@get "/datasets/{id}" function(req, id)
    local dsid
    try
        dsid = UUID(id)
    catch
        sleep(5)
        return HTTP.Response(422, Dict("error" => "invalid request", "detail" => "$id is not a valid UUID") |> JSON3.write)
    end

    # check availability
    ds::DataSet = read_dataset(dsid)
    if isnothing(ds) || ds.state != available
        sleep(5)
        return HTTP.Response(404, Dict("error" => "resource not found", "detail" => "there is no data set available with ID: $id") |> JSON3.write)
    end

    # check authorization
    if !ds.public && !req.context[:internal]
        sleep(5)
        return HTTP.Response(403, Dict("error" => "access denied", "detail" => "access to this data set is restricted") |> JSON3.write)
    end

    uri = download_uri(ds)
    download_name = download_filename(ds)
    update_dataset_downloads(dsid, ds.downloads += 1)

    return HTTP.Response(200, ["X-Accel-Redirect" => uri, "Content-Disposition" => "attachment; filename=\"$download_name\""])
end


#==  Additional inactive Data API endpoints  ==

@get "/datasets" function(req)
    available_ds = available_datasets(req.context[:internal])
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
=#
