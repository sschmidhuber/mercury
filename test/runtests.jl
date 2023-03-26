cd(@__DIR__)
include("../src/Mercury.jl")

using Test, UUIDs


@testset "Persistence Tests" begin
    # initialize flat file DB
    Mercury.initdb()
    @test !isnothing(Mercury.datasets)
    
    # create and read all
    dscount = length(Mercury.read_datasets())
    ds1 = Mercury.DataSet(id=uuid4(), filename="Test File 1.jpg", type=MIME("image/jpeg"), size=0)
    Mercury.create_dataset(ds1)
    @test dscount + 1 == Mercury.read_datasets() |> length

    # read one
    ds2 = Mercury.read_dataset(ds1.id)
    @test isequal(ds1, ds2)

    # update
    ds2.size = 100
    Mercury.update_dataset(ds2)
    ds3 = Mercury.read_dataset(ds1.id)
    @test ds3.size == 100

    # delete
    Mercury.delete_dataset(ds1.id)
    @test dscount == Mercury.read_datasets() |> length
    @test Mercury.read_dataset(ds1.id) === nothing
    @test_throws DomainError Mercury.update_dataset(ds1)
end;