using MergedIterators: 
    MergedIterators, MergedIterator, SingleIterator, @merge_and_process, 
    get_iterator_type, get_value_type, get_state_type, @custom_lt, IteratorProcess
using Test

@testset "single iterator" begin
    iter1 = 1:5
    wrapped_iter1 = SingleIterator{typeof(iter1), Int64, Int64}(iter1)

    for (i, j) ∈ zip(iter1, wrapped_iter1)
        @test i === j
    end

    iter2 = (1, 3.2, "Hello")
    wrapped_iter2 = SingleIterator{typeof(iter2), Union{fieldtypes(typeof(iter2))...}, Int64}(iter2)

    for (i, j) ∈ zip(iter2, wrapped_iter2)
        @test i === j
    end

    @test get_iterator_type(typeof(wrapped_iter1)) == typeof(iter1)
    @test get_iterator_type(typeof(wrapped_iter2)) == Tuple{Int64, Float64, String}
    @test get_value_type(typeof(wrapped_iter1)) == Int64
    @test get_value_type(typeof(wrapped_iter2)) == Union{Int64, Float64, String}
    @test get_state_type(typeof(wrapped_iter1)) == get_state_type(typeof(wrapped_iter2)) == Int64

    iter3 = ()
    wrapped_iter3 = SingleIterator{Tuple{}, Int64, Int64}(iter3)
    wrapped_iter4 = SingleIterator{Tuple{}, Float64, Float64}(iter3)
    for (i, j) ∈ wrapped_iter3
        error("This should not execute")
    end
end


@testset "merged iterator" begin
    iter1 = [3, 4, 5, 9]
    iter2 = [3.1, 3.9, 4.3, 9.2, 10]
    iter3 = ()
    iter4 = 1:6

    siter1 = SingleIterator{typeof(iter1), Int64, Int64}(iter1)
    siter2 = SingleIterator{typeof(iter2), Float64, Int64}(iter2)
    siter3 = SingleIterator{typeof(iter3), Float64, Float64}(iter3)
    siter4 = SingleIterator{typeof(iter4), Int64, Int64}(iter4)

    miter = MergedIterator(siter1, siter2, siter3, siter4)

    merged_result = [1, 2, 3, 3, 3.1, 3.9, 4, 4, 4.3, 5, 5, 6, 9, 9.2, 10]
    v = Vector{Any}()
    for x ∈ miter
        push!(v, x)
    end

    @test merged_result == v
    @test typeof(v[15]) === Float64

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

    @test merged_result2 == v2
end

@testset "merge macro" begin
    mutable struct SumProcess{T} <: IteratorProcess
        val::T
    end

    (s::SumProcess)(x) = begin
        s.val += x
        s.val
    end

    iter1 = [3, 4, 5, 9]
    iter2 = [3.1, 3.9, 4.3, 9.2, 10]
    iter3 = ()
    iter4 = 1:6

    result = sum(iter1; init=0) + sum(iter2; init=0) + sum(iter3; init=0) + sum(iter4; init=0)

    process = SumProcess(zero(Float64))
    @merge_and_process process iter1 iter2 iter3 iter4

    @test process.val == result

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

    @test collector.amounts == [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
end