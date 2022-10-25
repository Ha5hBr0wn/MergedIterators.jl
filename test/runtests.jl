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

struct Iter2{I1, I2}
    i1::I1
    i2::I2
end

mutable struct State2{V1, V2, S1, S2}
    v1::Union{V1, Nothing}
    v2::Union{V2, Nothing}
    s1::Union{S1, Nothing}
    s2::Union{S2, Nothing}
end

State2(::Nothing, ::Nothing, ::Nothing, ::Nothing) = State2{Nothing, Nothing, Nothing, Nothing}(nothing, nothing, nothing, nothing)
State2(::Nothing, v2::V2, ::Nothing, s2::S2) where {V2, S2} = State2{Nothing, V2, Nothing, S2}(nothing, v2, nothing, s2)
State2(v1::V1, ::Nothing, s1::S1, ::Nothing) where {V1, S1} = State2{V1, Nothing, S1, Nothing}(v1, nothing, s1, nothing)

Base.iterate(iter::Iter2) = begin
    next1 = iterate(iter.i1)
    next2 = iterate(iter.i2)

    if next1 === nothing && next2 === nothing
        return nothing
    
    elseif next1 === nothing
        v2, s2 = next2
        nextnext2 = iterate(iter.i2, s2)
        if nextnext2 === nothing
            return v2, State2(nothing, nothing, nothing, nothing)
        else
            nextv2, nexts2 = nextnext2
            return v2, State2(nothing, nextv2, nothing, nexts2)
        end
    
    elseif next2 === nothing
        v1, s1, = next1
        nextnext1 = iterate(iter.i1, s1)
        if nextnext1 === nothing
            return v1, State2(nothing, nothing, nothing, nothing)
        else
            nextv1, nexts1 = nextnext1
            return v1, State2(nextv1, nothing, nexts1, nothing)
        end
    
    else
        v1, s1 = next1
        v2, s2 = next2
        if isless(v1, v2)
            nextnext1 = iterate(iter.i1, s1)
            if nextnext1 === nothing
                return v1, State2(nothing, v2, nothing, s2)
            else
                nextv1, nexts1 = nextnext1
                return v1, State2(nextv1, v2, nexts1, s2)
            end
        else
            nextnext2 = iterate(iter.i2, s2)
            if nextnext2 === nothing
                return v2, State2(v1, nothing, s1, nothing)
            else
                nextv2, nexts2 = nextnext2
                return v2, State2(v1, nextv2, s1, nexts2)
            end
        end
    end
end

Base.iterate(iter::Iter2, state::State2) = begin
    if state.v1 === nothing && state.v2 === nothing
        return nothing

    elseif state.v1 === nothing
        next = iterate(iter.i2, state.s2)
        if next === nothing
            return state.v2, State2(nothing, nothing, nothing, nothing)
        else
            v2, s2 = next
            return state.v2, State2(nothing, v2, nothing, s2)
        end

    elseif state.v2 === nothing
        next = iterate(iter.i1, state.s1)
        if next === nothing
            return state.v1, State2(nothing, nothing, nothing, nothing)
        else
            v1, s1 = next
            return state.v1, State2(v1, nothing, s1, nothing)
        end

    else
        if isless(state.v1, state.v2)
            next = iterate(iter.i1, state.s1)
            if next === nothing
                return state.v1, State2(nothing, state.v2, nothing, state.s2)
            else
                v1, s1 = next
                return state.v1, State2(v1, state.v2, s1, state.s2)
            end
        else
            next = iterate(iter.i2, state.s2)
            if next === nothing
                return state.v2, State2(state.v1, nothing, state.s1, nothing)
            else
                v2, s2 = next
                return state.v2, State2(state.v1, v2, state.s1, s2)
            end
        end
    end
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

time_manual_merged_iter(mi::Iter2) = begin
    s = 0.0
    for x in mi
        s += x
    end
    s
end

const mmi = Iter2(a.iter, b.iter)

@btime time_merged_iter($mi)
@btime time_seperate_iters($a, $b)
@btime time_manual_merge_seperate_iters($a.iter, $b.iter)
@btime time_manual_merged_iter($mmi)