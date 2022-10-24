using MergedIterators: MergedIterator, SingleIterator
using BenchmarkTools

const a = SingleIterator{Vector{Float64}, Float64, Int64}(rand(10_000_000))
const b = SingleIterator{Vector{Float64}, Float64, Int64}(rand(10_000_000))

const mi = MergedIterator(a, b)

time_merged_iter(m::MergedIterator) = begin
    s = 0.0
    for x in m
        s += x
    end
    s
end

time_seperate_iters(i1, i2) = begin
    s = 0.0
    for x in i1
        s += x
    end
    for x in i2
        s += x
    end
    s
end

@btime time_merged_iter($mi)
@btime time_seperate_iters($a.iter, $b.iter)