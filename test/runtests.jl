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

mutable struct SumIteratorProcess
    s::Float64
end

SumIteratorProcess() = SumIteratorProcess(0.0)

(s::SumIteratorProcess)(input) = begin
    s.s += input
end

time_manual_merge_iters(a, b, s) = begin
    next_a = iterate(a)
    next_b = iterate(b)

    while next_a !== nothing || next_b !== nothing
        if next_a === nothing
            value_b, state_b = next_b
            s(value_b)
            next_b = iterate(b, state_b)
            continue

        elseif next_b === nothing
            value_a, state_a = next_a
            s(value_a)
            next_a = iterate(a, state_a)
            continue

        else
            value_a, state_a = next_a
            value_b, state_b = next_b
            if isless(value_a, value_b)
                s(value_a)
                next_a = iterate(a, state_a)
                continue
            else
                s(value_b)
                next_b = iterate(b, state_b)
                continue
            end
        end
    end
    s
end

time_manual_merge_iters(a, b, c, s) = begin
    next_a = iterate(a)
    next_b = iterate(b)
    next_c = iterate(c)

    while next_a !== nothing || next_b !== nothing || next_c !== nothing
        if next_a === nothing && next_b === nothing
            value_c, state_c = next_c
            s(value_c)
            next_c = iterate(c, state_c)

        elseif next_a === nothing && next_c === nothing
            value_b, state_b = next_b
            s(value_b)
            next_b = iterate(b, state_b)

        elseif next_b === nothing && next_c === nothing
            value_a, state_a = next_a
            s(value_a)
            next_a = iterate(a, state_a)

        elseif next_a === nothing
            value_b, state_b = next_b
            value_c, state_c = next_c
            isless(value_b, value_c) ? (s(value_b); next_b = iterate(b, state_b)) : (s(value_c); next_c = iterate(c, state_c))

        elseif next_b === nothing
            value_a, state_a = next_a
            value_c, state_c = next_c
            isless(value_a, value_c) ? (s(value_a); next_a = iterate(a, state_a)) : (s(value_c); next_c = iterate(c, state_c))

        elseif next_c === nothing
            value_a, state_a = next_a
            value_b, state_b = next_b
            isless(value_a, value_b) ? (s(value_a); next_a = iterate(a, state_a)) : (s(value_b); next_b = iterate(b, state_b))

        else
            value_a, state_a = next_a
            value_b, state_b = next_b
            value_c, state_c = next_c
            if isless(value_a, value_b)
                if isless(value_a, value_c)
                    s(value_a); next_a = iterate(a, state_a)
                else
                    s(value_c); next_c = iterate(c, state_c)
                end
            else
                if isless(value_b, value_c)
                    s(value_b); next_b = iterate(b, state_b)
                else
                    s(value_c); next_c = iterate(c, state_c)
                end
            end

            # min_value = min(value_a, value_b, value_c)
            # if min_value === value_a s(value_a); next_a = iterate(a, state_a)
            # elseif min_value === value_b s(value_b); next_b = iterate(b, state_b)
            # else s(value_c); next_c = iterate(c, state_c) end
        end
    end
end

all_nothings(nexts) = begin
    for next in nexts
        if next !== nothing return false end
    end
    return true
end

get_min_idx(nexts) = begin
    min = nothing
    min_idx = 0
    for (i, next) in enumerate(nexts)
        if next !== nothing && min !== nothing
            isless(min, next[1]) || (min = next[1]; min_idx = i)
        elseif min === nothing && next !== nothing
            min = next[1]; min_idx = i
        end
    end
    min_idx
end

time_general2_manual_merge_iters(s, iters...) = begin
    nexts = [iterate(iter) for iter in iters]

    println(@code_warntype all_nothings(nexts))
    println(@code_warntype get_min_idx(nexts))
    while !all_nothings(nexts)
        min_idx = get_min_idx(nexts)
        s(nexts[min_idx][1])
        nexts[min_idx] = iterate(iters[min_idx], nexts[min_idx][2])
    end
end

get_node_types(iters, nexts) = begin
    v = Vector{DataType}()
    for node in zip(iters, nexts)
        push!(v, typeof(node))
    end
    v
end

populate_heap!(heap, iters, nexts) = begin
    for node in zip(iters, nexts)
        node[1] === nothing || push!(heap, node)
    end
    nothing
end

run_process(ip, heap) = begin 
    while !isempty(heap)
        iter, (value, state) = pop!(heap)
        ip(value)
        next = iterate(iter, state)
        next === nothing || push!(heap, (iter, next))
    end
end

time_general_manual_merge_iters(ip, iters...) = begin
    nexts = map(iters) do iter
        iterate(iter)
    end
    heap = BinaryMinHeap{Union{get_node_types(iters, nexts)...}}()
    populate_heap!(heap, iters, nexts)    
    run_process(ip, heap)
end

# @btime time_merged_iter($mi)
# time_manual_merge_iters($a.iter, $b.iter, $c.iter, SumIteratorProcess())
# time_general_manual_merge_iters(SumIteratorProcess(), a.iter, b.iter, c.iter)
# @btime time_general2_manual_merge_iters(SumIteratorProcess(), $a.iter, $b.iter, $c.iter, 1:0)
time_general2_manual_merge_iters(SumIteratorProcess(), a.iter, b.iter, c.iter, 1:0)