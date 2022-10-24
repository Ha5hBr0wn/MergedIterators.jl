using MergedIterators: MergedIterator
using BenchmarkTools

const a = rand(10_000_000)
const b = rand(10_000_000)

const mi = MergedIterator([a, b])

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

@benchmark time_merged_iter(mi)
@benchmark time_seperate_iters(a, b)