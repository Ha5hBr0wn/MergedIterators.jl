using MergedIterators: MergedIterator, SingleIterator
using BenchmarkTools
using ProfileView: @profview

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

time_manual_merge_seperate_iters(i1, i2) = begin
    i1_index = 1
    i2_index = 1
    s = 0.0
    while !(i1_index > length(i1)) || !(i2_index > length(i2))
        if i1_index > length(i1)
            s += i2[i2_index]
            i2_index += 1
        elseif i2_index > length(i2)
            s += i1[i1_index]
            i1_index += 1
        else
            if i1[i1_index] < i2[i2_index]
                s += i1[i1_index]
                i1_index += 1
            else
                s += i2[i2_index]
                i2_index += 1
            end
        end
    end
    s
end

@profview time_merged_iter(mi)
@btime time_seperate_iters($a, $b)
@btime time_manual_merge_seperate_iters($a.iter, $b.iter)