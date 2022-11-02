module MergedIterators
    ######################### using statements #######################
    using DataStructures
    using Base: Order.lt, Order.Forward, Order.ForwardOrdering, Order.Ordering


    ####################### single iterator ##########################
    struct SingleIterator{I, V, S}
        iter::I
    end

    get_iterator_type(::Type{SingleIterator{I, V, S}}) where {I, V, S} = I

    get_value_type(::Type{SingleIterator{I, V, S}}) where {I, V, S} = V

    get_state_type(::Type{SingleIterator{I, V, S}}) where {I, V, S} = S

    Base.iterate(single_iterator::SingleIterator{I, V, S}) where {I, V, S}  = iterate(single_iterator.iter)::Union{Tuple{V, S}, Nothing}

    Base.iterate(single_iterator::SingleIterator{I, V, S}, state::S) where {I, V, S} = iterate(single_iterator.iter, state)::Union{Tuple{V, S}, Nothing}

    
    ########################### merged iterator ########################
    struct MergedIterator{T, O}
        single_iterators::T
    end

    MergedIterator(::O, single_iterators::Vararg{SingleIterator}) where O <: Ordering = begin
        T = Tuple{
            [
                typeof(single_iterator)
                for single_iterator in single_iterators
            ]...
        }
        MergedIterator{T, O}(single_iterators)
    end

    MergedIterator(single_iterators::Vararg{SingleIterator}) = MergedIterator(Forward, single_iterators...)

    struct MergedIteratorStateNode{I, V, S}
        iter::I
        value::V
        state::S
    end

    MergedIteratorStateNode(single_iterator::SingleIterator{I, V, S}, value::V, state::S) where {I, V, S} = begin
        MergedIteratorStateNode{I, V, S}(single_iterator.iter, value, state)
    end

    MergedIteratorStateNode(::SingleIterator{I, V, S}, ::V2, ::S2) where {I, V, S, V2, S2} = begin
        V == V2 || error("Value type not stable, expected $V but got $V2. Try changing the value type parameter to a Union for the SingleIterator")
        S == S2 || error("State type not stable, expected $S but got $S2. Try changing the state type parameter to a Union for the SingleIterator")
    end

    MergedIteratorStateNode(node::MergedIteratorStateNode{I, V, S}, value::V, state::S) where {I, V, S} = begin
        MergedIteratorStateNode{I, V, S}(node.iter, value, state)
    end

    MergedIteratorStateNode(::MergedIteratorStateNode{I, V, S}, ::V2, ::S2) where {I, V, S, V2, S2} = begin
        V == V2 || error("Value type not stable, expected $V but got $V2. Try changing the value type parameter to a Union for the SingleIterator")
        S == S2 || error("State type not stable, expected $S but got $S2. Try changing the state type parameter to a Union for the SingleIterator")
    end

    struct MergedIteratorState{T, O <: Ordering}
        heap::BinaryHeap{T, O}
    end

    MergedIteratorState(::MergedIterator{T, O}) where {T, O <: Ordering} = begin
        node_type = Union{
            [
                MergedIteratorStateNode{get_iterator_type(single_iterator_type), get_value_type(single_iterator_type), get_state_type(single_iterator_type)}
                for single_iterator_type in fieldtypes(T)
            ]...
        }
        MergedIteratorState{node_type, O}(BinaryHeap{node_type, O}())
    end

    Base.iterate(merged_iterator::MergedIterator) = begin
        merged_iterator_state = MergedIteratorState(merged_iterator)
        for single_iterator in merged_iterator.single_iterators
            next = iterate(single_iterator.iter)
            if next === nothing continue end
            push!(merged_iterator_state.heap, MergedIteratorStateNode(single_iterator, next...))
        end

        if isempty(merged_iterator_state.heap)
            nothing
        else
            first(merged_iterator_state.heap).value, merged_iterator_state
        end
    end

    Base.iterate(::MergedIterator, merged_iterator_state::MergedIteratorState) = begin
        node = pop!(merged_iterator_state.heap)
        next = iterate(node.iter, node.state)            
        if next !== nothing     
            push!(merged_iterator_state.heap, MergedIteratorStateNode(node, next...))
        elseif isempty(merged_iterator_state.heap)
            return nothing
        end
        first(merged_iterator_state.heap).value, merged_iterator_state
    end

    
    ###################### defining orderings ############################
    Base.Order.lt(::ForwardOrdering, a::MergedIteratorStateNode, b::MergedIteratorStateNode) = lt(Forward, a.value, b.value)

    macro custom_lt(lt_func)
        ordering_type = lt_func.args[1].args[2].args[end]
        unwrap_node_lt_func = quote
            Base.Order.lt(
                o::$ordering_type, 
                a::MergedIterators.MergedIteratorStateNode, 
                b::MergedIterators.MergedIteratorStateNode
            ) = Base.Order.lt(o, a.value, b.value)
        end
    
        quote
            $(esc(lt_func))
            $(esc(unwrap_node_lt_func))
        end
    end


    ###################### macro interface (highly efficient) ########################
    abstract type IteratorProcess end

    rank_key(x) = convert(Float64, x)

    check_inputs(process, iters...) = begin
        quote
            @assert $(esc(process)) isa MergedIterators.IteratorProcess
            @assert length($(esc(iters))) >= 2
        end
    end
    
    next_var(i) = Symbol("next_", i)
    
    next_vars_tuple(max_i) = begin
       s = "(" * join(["next_$i" for i in 1:max_i], ",") * ")"
        Meta.parse(s)
    end
    
    initial_setup(iters...) = begin
        v = Vector{Expr}()
        for (i, iter) in enumerate(iters)
            push!(v, :($(next_var(i)) = iterate($(esc(iter)))))
        end
        Expr(:block, v...)
    end
    
    while_condition(iters...) = begin
        Meta.parse(join(["next_$i !== nothing" for i in 1:length(iters)], " || "))
    end
    
    process_and_iterate(process, iter, i) = begin
        """
        $process($(next_var(i))[1])
        $(next_var(i)) = iterate($iter, $(next_var(i))[2])
        """
    end
    
    if_else_statements(process, iters...) = begin
        v = Vector{Expr}()
        for (i, iter) in enumerate(iters)    
            e = quote
                if min_idx == $i
                    $(esc(process))($(next_var(i))[1])
                    $(next_var(i)) = iterate($(esc(iter)), $(next_var(i))[2])
                    continue
                end
            end
            push!(v, e)
        end
        Expr(:block, v...)
    end
    
    while_loop(process, iters...) = begin
        while_condition_code = while_condition(iters...)
        if_else_statements_code = if_else_statements(process, iters...)
        
        quote
            while $while_condition_code
                min_idx = argmin(map(x -> x === nothing ? Inf : MergedIterators.rank_key(x[1]), $(next_vars_tuple(length(iters)))))
                $if_else_statements_code
            end
        end
    end
    
    macro merge_and_process(process, iters...) 
        check_inputs_code = check_inputs(process, iters...)
        initial_setup_code = initial_setup(iters...)
        while_loop_code = while_loop(process, iters...)
        
        quote
            $(check_inputs_code)
            $(initial_setup_code)
            $(while_loop_code)
            $(esc(process))
        end
    end

end