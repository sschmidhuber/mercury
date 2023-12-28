cd(@__DIR__)
ENV["MODE"] = "test"    # using "test" mode to stop mercury from starting the server itself

include("../src/Mercury.jl")

using Test, UUIDs, HTTP, JSON

@testset verbose=true "Mercury" begin
@testset "Persistence" begin
    # initialize flat file DB
    Mercury.initdb()
    @test !isnothing(Mercury.datasets)
    Mercury.correct_inconsistencies()
    
    # create and read all
    dscount = length(Mercury.read_datasets())
    file1 = Mercury.File("File 1", "", 1105637, MIME("image/jpeg"))
    file2 = Mercury.File("File 2", "", 9323, MIME("text/csv"))
    ds1 = Mercury.DataSet(uuid4(), "DataSet 1", ["Test Data"], 48, false, false, [file1, file2])
    ### iobuffer = open(joinpath("..","test", "data", "mercury.png"))

    Mercury.create_dataset(ds1)
    @test dscount + 1 == Mercury.read_datasets() |> length

    # read one
    ds2 = Mercury.read_dataset(ds1.id)
    @test isequal(ds1, ds2)

    # update
    ds2.label = "Test DataSet 1"
    Mercury.update_dataset(ds2)
    ds3 = Mercury.read_dataset(ds1.id)
    @test ds3.label == "Test DataSet 1"

    # delete
    Mercury.delete_dataset(ds1.id)
    @test (Mercury.read_dataset(ds1.id)).stage == Mercury.deleted

    #### here is a bug to fix, deleted state doesn't get written to DB
    # @show Mercury.read_dataset(ds1.id)

    Mercury.delete_dataset(ds1.id, hard=true, dbrecord=true)
    @test dscount == Mercury.read_datasets() |> length
    @test Mercury.read_dataset(ds1.id) === nothing
    @test_throws DomainError Mercury.update_dataset(ds1)
end

@testset "Common Functions" begin
    file1 = Mercury.File("File 1", "", 1105637, MIME("image/jpeg"))
    file2 = Mercury.File("File 2", "", 9323, MIME("text/csv"))
    ds1 = Mercury.DataSet(uuid4(), "DataSet 1", ["Test Data"], 48, false, false, [file1, file2])

    @test Mercury.storage_size(ds1) == file1.size + file2.size
end

#=@testset "API" begin
    try
        middleware = [Mercury.ip_segmentation]
        Mercury.serve(middleware=middleware, host="127.0.0.1", port=8123, async=true, access_log=nothing)

        request_header = ["X-Real-IP" => "192.168.0.2"]

        # upload single file
        data = [
            "label" => "Text File",
            "retention_time" => "1",
            "hidden" => "false",
            "public" => "false",
            "file" => HTTP.Multipart("\$pécial ¢haräcterß.txt", open(joinpath("..","test", "data", "\$pécial ¢haräcterß.txt")), "text/plain")
            ]
        body = HTTP.Form(data)
        res = HTTP.request("POST", "http://127.0.0.1:8123/datasets", request_header, body)

        res = res.body |> String |> JSON.parse
        id1 = res["id"]
        ds1 = Mercury.read_dataset(UUID(id1))
        @test ds1.label == "Text File"

        # upload multiple files
        data = [
            "label" => "Test Data Set",
            "retention_time" => "1",
            "hidden" => "false",
            "public" => "false",
            "file1" => HTTP.Multipart("code_1.74.3-1673284829_amd64.deb", open(joinpath("..","test", "data", "code_1.74.3-1673284829_amd64.deb")), "application/octet-stream"),
            "file2" => HTTP.Multipart("Sintel.mp4", open(joinpath("..","test", "data", "Sintel.mp4")), "video/mp4"),
            "file3" => HTTP.Multipart("DALL·E 2023-02-23 23.42.38 - painting of a friendly dragon.png", open(joinpath("..","test", "data", "DALL·E 2023-02-23 23.42.38 - painting of a friendly dragon.png")), "image/png")
        ]
        body = HTTP.Form(data)
        res = HTTP.request("POST", "http://127.0.0.1:8123/datasets", request_header, body)

        res = res.body |> String |> JSON.parse
        id2 = res["id"]
        ds2 = Mercury.read_dataset(UUID(id2))
        @test ds1.label == "Text File"
        Mercury.config["disable_malware_check"] = false

        # get status
        for _ in 1:2
            res = HTTP.request("GET", "http://127.0.0.1:8123/datasets/$id2/properties", request_header)
            res = res.body |> String |> JSON.parse
            @info "stage: $(res["stage"])"
            @test res["stage"] == "scanned" || res["stage"] == "prepared" ||res["stage"] == "available"
            sleep(2)
        end

        HTTP.request("GET", "http://127.0.0.1:8123/status", request_header)
    finally
        Mercury.stop_webserver()
    end
end=#

# clean up ENV variable
delete!(ENV, "MODE")
end;