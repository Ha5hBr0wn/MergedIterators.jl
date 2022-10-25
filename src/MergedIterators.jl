module MergedIterators
    using DataStructures

    struct SingleIterator{I, V, S}
        iter::I
    end

    get_iterator_type(::SingleIterator{I, V, S}) where {I, V, S} = I

    get_value_type(::SingleIterator{I, V, S}) where {I, V, S} = V

    get_state_type(::SingleIterator{I, V, S}) where {I, V, S} = S

    Base.iterate(single_iterator::SingleIterator{I, V, S}) where {I, V, S} = begin
        iterate(single_iterator.iter)
    end

    Base.iterate(single_iterator::SingleIterator{I, V, S}, state::S) where {I, V, S} = begin
        iterate(single_iterator.iter, state)
    end

    struct MergedIterator{T}
        single_iterators::T
    end

    MergedIterator(single_iterators::Vararg{SingleIterator}) = begin
        T = Tuple{
            [
                typeof(single_iterator)
                for single_iterator in single_iterators
            ]...
        }
        MergedIterator{T}(single_iterators)
    end

    struct MergedIteratorStateNode{I, V, S}
        iter::I
        value::V
        state::S
    end

    MergedIteratorStateNode(single_iterator::SingleIterator{I, V, S}, value::V, state::S) where {I, V, S} = begin
        MergedIteratorStateNode{I, V, S}(single_iterator.iter, value, state)
    end

    MergedIteratorStateNode(node::MergedIteratorStateNode{I, V, S}, value::V, state::S) where {I, V, S} = begin
        MergedIteratorStateNode{I, V, S}(node.iter, value, state)
    end

    struct MergedIteratorState{T}
        heap::BinaryMinHeap{T}
    end

    MergedIteratorState(merged_iterator::MergedIterator) = begin
        node_type = Union{
            [
                MergedIteratorStateNode{get_iterator_type(single_iterator), get_value_type(single_iterator), get_state_type(single_iterator)}
                for single_iterator in merged_iterator.single_iterators
            ]...
        }
        MergedIteratorState{node_type}(BinaryMinHeap{node_type}())
    end

    Base.isless(a::MergedIteratorStateNode, b::MergedIteratorStateNode) = begin
        isless(a.value, b.value)
    end

    Base.isequal(a::MergedIteratorStateNode, b::MergedIteratorStateNode) = begin
        isequal(a.value, b.value)
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

end