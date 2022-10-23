module MergedIterators
    using DataStructures

    struct MergedIterator
        iterators
    end

    struct MergedIteratorStateNode
        iterator
        value
        state
    end

    struct MergedIteratorState
        heap::BinaryMinHeap{MergedIteratorStateNode}
    end

    Base.isless(a::MergedIteratorStateNode, b::MergedIteratorStateNode) = begin
        isless(a.value, b.value)
    end

    Base.isequal(a::MergedIteratorStateNode, b::MergedIteratorStateNode) = begin
        isequal(a.value, b.value)
    end

    Base.iterate(iter::MergedIterator) = begin
        heap = BinaryMinHeap{MergedIteratorStateNode}()
        for component_iter in iter.iterators
            next = iterate(component_iter)
            if next === nothing continue end
            push!(heap, MergedIteratorStateNode(component_iter, next...))
        end

        if isempty(heap)
            nothing
        else
            first(heap).value, MergedIteratorState(heap)
        end
    end

    Base.iterate(::MergedIterator, state::MergedIteratorState) = begin
        node = pop!(state.heap)
        next = iterate(node.iterator, node.state)            
        if next !== nothing     
            push!(state.heap, MergedIteratorStateNode(node.iterator, next...))
        elseif isempty(state.heap)
            return nothing
        end
        first(state.heap).value, state
    end

end
