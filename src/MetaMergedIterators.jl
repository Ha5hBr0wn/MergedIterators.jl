# merge_and_process(ordering::Base.Order.Ordering, process::MergedIterators.IteratorProcess, i1, i2) = begin
#     next_i1 = iterate(i1)
#     next_i2 = iterate(i2)

#     while i1 !== nothing || i2 !== nothing
#         if i1 === nothing
#             process(next_i2[1])
#             next_i2 = iterate(i2, next_i2[2])
#         elseif i2 === nothing
#             process(next_i1[1])
#             next_i1 = iterate(i1, next_i1[2])
#         else
#             if Base.Order.lt(ordering, next_i1[1], next_i2[1])
#                 process(next_i1[1])
#                 next_i1 = iterate(i1, next_i1[2])
#             else
#                 process(next_i2[1])
#                 next_i2 = iterate(i2, next_i2[2])
#             end
#         end
#     end
# end


merge_and_process(ordering::Base.Order.Ordering, process::MergedIterators.IteratorProcess, i1, i2) = begin
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



using MergedIterators

check_inputs(ordering, process) = begin
    quote
        @assert $ordering isa Base.Order.Ordering
        @assert $process isa MergedIterators.IteratorProcess
    end
end

initial_setup(iters...) = begin
    quote
        d = (i => iterate(iter) for iter in $iters)
    end
end

while_condition(iters...) = begin
    Meta.parse(join(["d[$i] !== nothing" for i in 1:length(iters)], " || "))
end

while_loop(ordering, process, iters...) = begin
    while_condition_code = while_condition(iters...)
    
    quote
        while $while_condition_code
            
        end
    end
end

macro merge_and_process(ordering, process, iters...)
    check_inputs_code = check_inputs(ordering, process)
    initial_setup_code = initial_setup(iters...)
    while_loop_code = while_loop(ordering, process, iters...)

    quote
        $check_inputs_code
        $initial_setup_code
        $while_loop_code
    end
end