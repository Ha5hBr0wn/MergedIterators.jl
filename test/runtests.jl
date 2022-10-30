using MergedIterators: MergedIterator, SingleIterator
using BenchmarkTools
using DataStructures

const a = SingleIterator{Vector{Int32}, Int32, Int64}(rand(Int32, 10_000_000))
const b = SingleIterator{Vector{Int8}, Int8, Int64}(rand(Int8, 10_000_000))
const c = SingleIterator{Vector{Int16}, Int16, Int64}(rand(Int16, 10_000_000))

const d = SingleIterator{Vector{Float64}, Float64, Int64}(rand(10_000_000))
const e = SingleIterator{Vector{Float64}, Float64, Int64}(rand(10_000_000))

const mi = MergedIterator(d, e)

mutable struct SumProcess
    s::Float64
end

(s::SumProcess)(x) = begin
    s.s += x
end

time_merged_iter(m::MergedIterator, process) = begin
    for x in m
        process(x)
    end
end

@btime time_merged_iter($mi, SumProcess(0))