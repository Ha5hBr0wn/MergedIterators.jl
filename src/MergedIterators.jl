module MergedIterators
    using DataStructures

    struct SingleIterator{I, V, S}
        iter::I
    end

    get_iterator_type(::SingleIterator{I, V, S}) where {I, V, S} = I

    get_value_type(::SingleIterator{I, V, S}) where {I, V, S} = V

    get_state_type(::SingleIterator{I, V, S}) where {I, V, S} = S

    Base.iterate(single_iterator::SingleIterator{I, V, S}) where {I, V, S} = begin
        iterate(single_iterator.iter)::Union{Tuple{V, S}, Nothing}
    end

    Base.iterate(single_iterator::SingleIterator{I, V, S}, state::S) where {I, V, S} = begin
        iterate(single_iterator.iter, state)::Union{Tuple{V, S}, Nothing}
    end

    struct MergedIterator{T}
        single_iterators::T
    end

    MergedIterator(single_iterators...) = begin
        T = Tuple{
            [
                typeof(single_iterator)
                for single_iterator in single_iterators
            ]...
        }
        MergedIterator{T}(single_iterators)
    end

    mutable struct MIStateNode{I, V, S}
        const iter::I
        value::Union{V, Nothing}
        state::Union{S, Nothing}
    end

    get_iterator_type(::MIStateNode{I, V, S}) where {I, V, S} = I

    get_value_type(::MIStateNode{I, V, S}) where {I, V, S} = V

    get_state_type(::MIStateNode{I, V, S}) where {I, V, S} = S

    Base.isless(a::MIStateNode, b::MIStateNode) = begin
        a.value === nothing && return false
        b.value === nothing && return true
        isless(a.value, b.value)
    end

    Base.isequal(a::MIStateNode, b::MIStateNode) = begin
        isequal(a.value, b.value)
    end

    mutable struct MIState{T}
        const state_nodes::T
        min_idx::Int64
    end

    MIState(state_nodes...) = begin
        T = Tuple{
            [
                typeof(state_node)
                for state_node in state_nodes
            ]...
        }
        MIState{T}(state_nodes, 0)
    end

    all_nothing(state_nodes) = begin
        for node in state_nodes
            node.value === nothing || return false
        end
        true
    end

    add_state_node!(state_nodes, single_iterator) = begin
        next = iterate(single_iterator.iter)
        if next === nothing
            push!(
                state_nodes, 
                MIStateNode{
                    get_iterator_type(single_iterator), get_value_type(single_iterator), get_state_type(single_iterator)
                }(single_iterator.iter, nothing, nothing)
            )
        else
            push!(
                state_nodes, 
                MIStateNode{
                    get_iterator_type(single_iterator), get_value_type(single_iterator), get_state_type(single_iterator)
                }(single_iterator.iter, next...)
            )
        end
        nothing
    end
    
    create_state_nodes(merged_iterator) = begin
        state_nodes = Vector{MIStateNode}()
        for single_iterator in merged_iterator.single_iterators
            add_state_node!(state_nodes, single_iterator)
        end
        state_nodes
    end

    update_state_node!(state_node, next) = begin
        if next === nothing
            state_node.value = nothing
            state_node.state = nothing
        else
            state_node.value, state_node.state = next
        end
        nothing
    end

    update_min_idx_and_yield!(state) = begin
        if all_nothing(state.state_nodes)
            nothing
        else
            state.min_idx = argmin(state.state_nodes)
            state.state_nodes[state.min_idx].value, state
        end
    end
    
    Base.iterate(merged_iterator::MergedIterator) = begin
        state = MIState(create_state_nodes(merged_iterator)...)
        update_min_idx_and_yield!(state)
    end

    Base.iterate(::MergedIterator{T}, state::MIState{U}) where {T, U} = begin
        node = state.state_nodes[state.min_idx]
        next = iterate(node.iter, node.state)
        update_state_node!(node, next)
        update_min_idx_and_yield!(state)
    end

end