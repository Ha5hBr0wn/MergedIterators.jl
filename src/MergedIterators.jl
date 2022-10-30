module MergedIterators
    using DataStructures
    using Base: Order.lt, Order.Forward, Order.ForwardOrdering, Order.Ordering

    struct SingleIterator{I, V, S}
        iter::I
    end

    get_iterator_type(::Type{SingleIterator{I, V, S}}) where {I, V, S} = I

    get_value_type(::Type{SingleIterator{I, V, S}}) where {I, V, S} = V

    get_state_type(::Type{SingleIterator{I, V, S}}) where {I, V, S} = S

    Base.iterate(single_iterator::SingleIterator)  = iterate(single_iterator.iter)

    Base.iterate(single_iterator::SingleIterator{I, V, S}, state::S) where {I, V, S} = iterate(single_iterator.iter, state)

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

    MergedIteratorStateNode(node::MergedIteratorStateNode{I, V, S}, value::V, state::S) where {I, V, S} = begin
        MergedIteratorStateNode{I, V, S}(node.iter, value, state)
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

    Base.Order.lt(ordering::O, a::MergedIteratorStateNode, b::MergedIteratorStateNode) where O <: Ordering = lt(ordering, a.value, b.value)

    Base.Order.lt(::ForwardOrdering, a::MergedIteratorStateNode, b::MergedIteratorStateNode) = lt(Forward, a.value, b.value)

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

    abstract type IteratorProcess end

    struct SumProcess <: IteratorProcess
        s::Float64
    end

    SumProcess() = SumProcess(0.0)

end