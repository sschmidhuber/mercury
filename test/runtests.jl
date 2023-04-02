cd(@__DIR__)
include("../src/Mercury.jl")

using Test, UUIDs, HTTP, JSON

@testset "Persistence" begin
    # initialize flat file DB
    Mercury.initdb()
    @test !isnothing(Mercury.datasets)
    Mercury.correct_inconsistencies()
    
    # create and read all
    dscount = length(Mercury.read_datasets())
    ds1 = Mercury.DataSet(uuid4(), "DataSet 1", ["Test Data"], ["Test File 1.jpg"], 1, [MIME("image/jpeg")], [1105637])
    iobuffer = open(joinpath("..","test", "data", "mercury.png"))

    #### the iobuffer is not getting processed correctly, this is a bug int he test

    Mercury.create_dataset(ds1, iobuffer)
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

    Mercury.delete_dataset(ds1.id, purge=true)
    @test dscount == Mercury.read_datasets() |> length
    @test Mercury.read_dataset(ds1.id) === nothing
    @test_throws DomainError Mercury.update_dataset(ds1)
end;

@testset "API" begin
    try
        Mercury.serve(host="127.0.0.1", port=8123, async=true, access_log=nothing)

        # upload single file
        data = Dict(
            "label" => "Text File",
            "file" => HTTP.Multipart("\$pécial ¢haräcterß.txt", open(joinpath("..","test", "data", "\$pécial ¢haräcterß.txt")), "text/plain")
        )
        body = HTTP.Form(data)
        res = HTTP.request("POST", "http://127.0.0.1:8123/datasets", [], body)

        res = res.body |> String |> JSON.parse
        id1 = res["id"]
        ds1 = Mercury.read_dataset(UUID(id1))
        @test ds1.label == "Text File"

        # upload multiple files
        data = Dict(
            "label" => "Test Data Set",
            "file1" => HTTP.Multipart("code_1.74.3-1673284829_amd64.deb", open(joinpath("..","test", "data", "code_1.74.3-1673284829_amd64.deb")), "application/octet-stream"),
            "file2" => HTTP.Multipart("Sintel.mp4", open(joinpath("..","test", "data", "Sintel.mp4")), "video/mp4"),
            "file3" => HTTP.Multipart("DALL·E 2023-02-23 23.42.38 - painting of a friendly dragon.png", open(joinpath("..","test", "data", "DALL·E 2023-02-23 23.42.38 - painting of a friendly dragon.png")), "image/png")
        )
        body = HTTP.Form(data)
        res = HTTP.request("POST", "http://127.0.0.1:8123/datasets", [], body)

        res = res.body |> String |> JSON.parse
        id2 = res["id"]
        ds2 = Mercury.read_dataset(UUID(id2))
        @test ds1.label == "Text File"

        # get status
        for _ in 1:5
            res = HTTP.request("GET", "http://127.0.0.1:8123/datasets/$id2/status")
            res = res.body |> String |> JSON.parse
            @info "$(res["label"]) stage: $(res["stage"])"
            sleep(1)
        end

        HTTP.request("GET", "http://127.0.0.1:8123/status")
    finally
        Mercury.terminate()
    end
end;