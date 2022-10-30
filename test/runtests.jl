using MergedIterators: MergedIterator, SingleIterator
using BenchmarkTools
using DataStructures
using ProfileView: @profview

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

merge_and_process(process, i1, i2) = begin
    next_i1 = iterate(i1)
    next_i2 = iterate(i2)

    while next_i1 !== nothing || next_i2 !== nothing
        min_idx = argmin(map(x -> x === nothing ? Inf : x[1], (next_i1, next_i2)))
        if min_idx == 1
            process(next_i1[1])
            next_i1 = iterate(i1, next_i1[2])
        else
            process(next_i2[1])
            next_i2 = iterate(i2, next_i2[2])
        end
    end
end

# merge_and_process(process, i1, i2) = begin
#     next_i1 = iterate(i1)
#     next_i2 = iterate(i2)

#     while next_i1 !== nothing || next_i2 !== nothing
#         if next_i1 === nothing
#             process(next_i2[1])
#             next_i2 = iterate(i2, next_i2[2])
#         elseif next_i2 === nothing
#             process(next_i1[1])
#             next_i1 = iterate(i1, next_i1[2])
#         else
#             if Base.Order.lt(Base.Order.Forward, next_i1[1], next_i2[1])
#                 process(next_i1[1])
#                 next_i1 = iterate(i1, next_i1[2])
#             else
#                 process(next_i2[1])
#                 next_i2 = iterate(i2, next_i2[2])
#             end
#         end
#     end
# end

@btime merge_and_process(SumProcess(0.0), $d, $e)