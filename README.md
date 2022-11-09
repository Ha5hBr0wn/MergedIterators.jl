# Introduction
This module provides utilities for iterating over multiple type stable iterators in an ordered fashion. That is provided n iterators that iterate in a non-decreasing fashion we want a single iterator that iterates over
all elements in all n iterators in a non-decreasing fashion. 

The module has two interfaces. A macro interface and an object interface. The macro interface is recommended as it is signifcantly more performant. The object interface is only recommended in the case where you are merging many iterators (more than 10 roughly), or if performance does not matter. 

The name `MergedIterators` must be in scope even if you do not use it to qualify names (i.e when you directly import or use the functions inside the module). This is because the macros `@merge_and_process` and `@custom_lt` expect it to be there. 

In the example code snippets you may need to import or use the appropirate definitions before they work. 

# Macro Interface
The macro `@merge_and_process`, the abstract class `IteratorProcess`, and the function `rank_key` form the macro interface. 

`@merge_and_process` takes as input an `IteratorProcess` followed by a variable number of iterators. 

One should extend `IteratorProcess` with a function like object that can 
handle the outputs of the iterators. This represents the process portion of `@merge_and_process`. 

The `rank_key` function maps an output of the iterators to a `Float64`. By default `rank_key` simply converts its input to `Float64`. Processing will happen in increasing order as according to the `rank_key` function. 

Below is an example of using this interface: 

    struct Message
        timestamp::Int64
        amount::Float64
    end

    MergedIterators.rank_key(m::Message) = m.amount

    struct CollectAmounts <: IteratorProcess
        amounts::Vector{Float64}
    end

    (ca::CollectAmounts)(x::Message) = begin
        push!(ca.amounts, x.amount)
        nothing
    end

    iter1 = [
        Message(1, 1),
        Message(3, 3),
        Message(7, 7)
    ]

    iter2 = [
        Message(2, 2),
        Message(4, 4), 
        Message(5, 5),
        Message(6, 6),
        Message(8, 8), 
        Message(10, 10)
    ]

    iter3 = [
        Message(0, 0), 
        Message(9, 9)
    ]

    iter4 = []

    collector = CollectAmounts([])

    @merge_and_process collector iter1 iter2 iter3 iter4

    collector.amounts == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10] # true

# Object Interface
The objects `SingleIterator` and `MergedIterator` and the macro `@custom_lt` form the object interface. 

`SinlgeIterator{I, V, S}` wraps any type stable iterator. `I` ist the type of the iterator, `V` is the type of the values coming out of the iterator (not including the `nothing` at the end) and `S` is the type of the state of the iterator. 

`MergedIterator{T, O}` represents a collection of single iterators. `T` is the type of the tuple of the included iterators but the user does not need to worry about that. `O` is the `Base.Order.Ordering` that the iterator will use. By default the iterator will use `Base.Order.ForwardOrdering`.

`@custom_lt` is used in front of adding a method to `Base.Order.lt` that you want to use with your own `Ordering` type. The macro simply defines a method of `Base.Order.lt` for an internal type so that the library can do its job. Internally that method is already defined when using a `Base.Order.ForwardOrdering` so if you are simply using that `Ordering` you don't need to use the macro in front of your method definition. You only need it when using your own `Ordering`. 

Below is an example of using this interface: 

    iter5 = [-2, 3, -5, 6]
    iter6 = (0, -1.2, -2.4, 2.9, 3.4, -5.6, -9)

    siter5 = SingleIterator{typeof(iter5), Int64, Int64}(iter5)
    siter6 = SingleIterator{typeof(iter6), Real, Int64}(iter6)

    struct AbsOrder <: Base.Order.Ordering end
    
    @custom_lt Base.Order.lt(::AbsOrder, a, b) = Base.Order.lt(Base.Order.Forward, abs(a), abs(b))

    miter2 = MergedIterator(AbsOrder(), siter5, siter6)

    merged_result2 = [0, -1.2, -2, -2.4, 2.9, 3, 3.4, -5, -5.6, 6, -9]
    v2 = Vector{Any}()
    for x ∈ miter2
        push!(v2, x)
    end

    merged_result2 == v2 # true