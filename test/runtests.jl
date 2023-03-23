cd(@__DIR__)
include("../src/Mercury.jl")

using Test


@testset "Persistence Tests" begin
    Mercury.initdb()
    @test !isnothing(Mercury.datasets)
end;