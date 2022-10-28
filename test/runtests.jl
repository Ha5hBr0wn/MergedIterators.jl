using MergedIterators: MergedIterator, SingleIterator
using BenchmarkTools
using DataStructures

const a = SingleIterator{Vector{Int32}, Int32, Int64}(rand(Int32, 10_000_000))
const b = SingleIterator{Vector{Int8}, Int8, Int64}(rand(Int8, 10_000_000))
const c = SingleIterator{Vector{Int16}, Int16, Int64}(rand(Int16, 10_000_000))

const mi = MergedIterator(a, b)

time_merged_iter(m::MergedIterator) = begin
    s = 0.0
    for x in m
        s += x
    end
    s
end

@btime time_merged_iter(mi)