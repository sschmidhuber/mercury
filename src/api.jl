## router

restricted = router("", tags=["restricted"], middleware=[internal])


## endpoints

@get "/" function()
    redirect("client/index.html")
end


@get "/health" function()
    healthcheck()
end


@get "/status" function(req)
    status(req.context[:internal])
end


@get "/config" function(req)
    clientconfig(req.context[:internal])
end

@post restricted("/datasets") function(req)
    # validate request
    @debug "validate request"
    contenttype = HTTP.headers(req, "Content-Type")
    if isempty(contenttype) || !contains(contenttype[1], "multipart/form-data")
        return HTTP.Response(415, Dict("error" => "invalid Content-Type", "detail" => "Expect \"multipart/form-data\"") |> JSON.json)
    end

    content = HTTP.parse_multipart_form(req)
    if content |> isnothing
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "parsing multipart form failed") |> JSON.json)
    end

    @debug "process request"
    # process request
    id = uuid4()
    filenames = map(c -> c.filename, content[5:end])
    types = map(c -> c.contenttype |> MIME, content[5:end])
    iobuffers = map(c -> c.data, content[5:end])
    sizes = map(io -> bytesavailable(io), iobuffers)

    
    label = content[1].data.data |> String
    if label == ""
        if length(filenames) == 1
            label = filenames[1]
        else
            label = "Data Set $(today())"
        end
    end

    local retention_time
    try
        retention_time = parse(Int, content[2].data.data |> String)
    catch err
        @warn "couldn't parse \"retention_time\""
        showerror(stderr, err)
        retention_time = config["retention"]["default"]
    end

    local hidden
    try
        hidden = parse(Bool, content[3].data.data |> String)
    catch err
        @warn "couldn't parse \"hidden\""
        showerror(stderr, err)
        hidden = false
    end

    local public
    try
        public = parse(Bool, content[4].data.data |> String)
    catch err
        @warn "couldn't parse \"public\""
        showerror(stderr, err)
        public = false
    end

    # validate fields
    if retention_time < config["retention"]["min"] || retention_time > config["retention"]["max"]
        return HTTP.Response(400, Dict("error" => "invalid request", "detail" => "retention time: $retention_time, out of bounds ($(config["retenion"]["min"])-$(config["retention"]["max"]))") |> JSON.json)
    end
    if isempty(iobuffers)
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "file missing") |> JSON.json)
    end
    if isempty(filenames) || filenames[1] == ""
        return HTTP.Response(422, Dict("error" => "invalid request content", "detail" => "filename missing") |> JSON.json)
    end
    if length(filenames) > config["limits"]["filenumber_per_dataset"]
        return HTTP.Response(413, Dict("error" => "dataset exceeds max file number", "detail" => "dataset exceeds max file number of $(config["limits"]["filenumber_per_dataset"])") |> JSON.json)
    end
    for i in eachindex(sizes)
        if sizes[i] > config["limits"]["filesize"]
            return HTTP.Response(413, Dict("error" => "file size exceeds limit", "detail" => "file size exceeds limit of $(config["limits"]["filesize"] |> format_size)") |> JSON.json)
        end
    end
    if sum(sizes) > config["limits"]["datasetsize"]
        return HTTP.Response(413, Dict("error" => "dataset exceeds size limit", "detail" => "dataset exceeds size limit of $(config["limits"]["datasetsize"] |> format_size)") |> JSON.json)
    end
    
    if 1 + count_ds() > config["limits"]["datasetnumber"]
        return HTTP.Response(507, Dict("error" => "maximum number of datasets exceeded", "detail" => "limit of $(config["limits"]["datasetnumber"]) datasets exceeded") |> JSON.json)
    end
    if sum(sizes) > available_storage()
        return HTTP.Response(507, Dict("error" => "storage limit exceeded", "detail" => "storage limit of $(config["limits"]["storage"] |> format_size) exceeded") |> JSON.json)
    end

    # add new DataSet and trigger further processing
    dataset = add_dataset(id, label, retention_time, hidden, public, filenames, types, sizes, iobuffers)
    # Threads.@spawn  ##  @spawn lead to an memory leak, using async as workaround for now
    @async process_dataset($id)

    return HTTP.Response(201, dataset |> dataset_to_dict |> JSON.json)
end


@get "/datasets" function(req)
    available_datasets(req.context[:internal])
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
    props = properties(dsid)
    if isnothing(props) || props["stage"] != available
        sleep(5)
        return HTTP.Response(404, Dict("error" => "resource not found", "detail" => "there is no data set available with ID: $id") |> JSON.json)
    end

    # check authorization
    if !props["public"] && !req.context[:internal]
        sleep(5)
        return HTTP.Response(403, Dict("error" => "access denied", "detail" => "access to this data set is restricted") |> JSON.json)
    end

    uri = get_download_uri(dsid)
    increment_download_counter(dsid)

    return HTTP.Response(200, ["X-Accel-Redirect" => uri, "Content-Disposition" => "attachment; filename=\"$(props["download_filename"])\""])
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