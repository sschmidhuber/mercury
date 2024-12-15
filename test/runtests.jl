cd(@__DIR__)
ENV["MODE"] = "test"    # using "test" mode to stop mercury from starting the server itself

include("../src/Mercury.jl")

using HTTP
using MIMEs
using SQLite
using Test
using UUIDs


"""
    create_datasets(count)

Create the given number of datasets, with random properties and files.
"""
function mock_datasets(count)::Vector{Mercury.DataSet}
    datasets = []
    for i in 1:count
        files = [Mercury.File("File $n", isodd(n) ? "" : "/directory/", rand(1_000:100_000_000_000), mime_from_extension(rand([".png", ".pdf", ".jpeg", ".mp3", ".odt", ".xlsx", ".csv"]))) for n=1:rand(1:20)]
        push!(datasets, Mercury.DataSet(uuid4(), "DataSet $i", [], rand(1:100), rand([true, false]), rand([true, false]), files))
    end

    return datasets
end


@testset verbose=true "Mercury" begin

    # create mock data
    mockdata = mock_datasets(200)
    Mercury.config["limits"]["storage"] = 1000_000_000_000_000

@testset "Persistence" begin
    # test CRUD operations
    Mercury.create_dataset.(mockdata)
    datasets = Mercury.read_datasets(100,1)
    @test length(datasets) == 100

    randomds = only(rand(datasets, 1))
    @test randomds isa Mercury.DataSet

    specificds = Mercury.read_dataset(randomds.id)
    @test specificds.id == randomds.id

    Mercury.delete_dataset_soft(specificds.id)
    @test Mercury.read_dataset_stage(specificds.id) == Mercury.deleted

    Mercury.delete_dataset_hard(specificds.id)
    @test isnothing(Mercury.read_dataset(specificds.id))
end

@testset "Service" begin
    randomds = rand(Mercury.read_datasets(), 180)
    foreach(randomds) do ds
        Mercury.update_dataset_stage(ds.id, rand([Mercury.available, Mercury.scanned, Mercury.deleted]))
    end
    storage_status_internal = Mercury.storage_status(true)
    storage_status_public = Mercury.storage_status(false)
    
    @test storage_status_internal isa Mercury.StorageStatus
    @test storage_status_public isa Mercury.StorageStatus
    @test storage_status_internal.count_ds >= storage_status_public.count_ds
    @test storage_status_internal.count_files >= storage_status_public.count_files
end

@testset "Common" begin
    file1 = Mercury.File("File 1", "", 1105637, MIME("image/jpeg"))
    file2 = Mercury.File("File 2", "", 9323, MIME("text/csv"))
    ds1 = Mercury.DataSet(uuid4(), "DataSet 1", ["Test Data"], 48, false, false, [file1, file2])

    @test Mercury.storage_size(ds1) == file1.size + file2.size
end

#=

To make this work the a mercury client in julia needs to be implemented, using the new API

@testset "API" begin
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
        @show data
        body = HTTP.Form(data)
        @show body
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


# clean up
delete!(ENV, "MODE")
close(Mercury.db)

end;