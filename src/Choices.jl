"""
Support for nondeterministic programming using iterable, backtracking Choices
and a special method of the |> operator for combining them with (anonymous)
functions (which stand in for continuations). This is as close as we can get to
McCarthy's amb operator in Julia, given that it doesn't have call/cc or
anything like it.
"""
module Choices

export choose, fail, cut

"""
    Choice{T}

Represents a call to choose() whose options (of type T) we have not yet fully
explored, as well as the overall nondeterministic computation that this choice
is at the end of, and the collection of its remaining successful results.

# Example
```jldoctest
get_first_part() = choose("razzle", "root")
get_second_part() = choose("beer", "dazzle")
function check_pair(first_part, second_part)
  length(first_part) == length(second_part) || fail()
  return (first_part, second_part)
end
get_both_parts() =
  get_first_part() |> first_part ->
  get_second_part() |> second_part ->
  check_pair(first_part, second_part)
[get_both_parts()...]

# output

2-element Array{Tuple{String,String},1}:
 ("razzle", "dazzle")
 ("root", "beer")
```

See also [`choose`](@ref), [`|>`](@ref), [`fail`](@ref), and [`cut`](@ref).
"""
struct Choice{O,R}
  # an iterable collection of the options for this choice
  options::O
  # the Choice we should backtrack to (if any) if we run out of options
  back::Union{Choice,Nothing}
  # the function (or at least something callable) to pass the next option to
  receive::R
  # when we create a Choice, store it in task-local storage
  function Choice(options::O, back::Union{Choice,Nothing}, receive::R) where {O, R}
    c = new{O,R}(options, back, receive)
    task_local_storage(:previous_choice, c)
    return c
  end
end

function Base.show(io::IO, x::Choice)
  print(io, "(choose from ", x.options)
  identity === x.receive ||
    print(io, " and call ",
          (occursin(r"^\w+$", string(nameof(x.receive))) ?
	    x.receive : "a nontrivial function"))
  isnothing(x.back) || print(io, " or go back to ", x.back)
  print(io, ")")
end

"""
    choose(options[, back::Choice])

Make a Choice among the given options, backtracking to the given Choice if
those options run out. If back isn't given, backtrack to the previous Choice
made in this Task, if any.

This form accepts one iterator of options, and it will only be iterated as the
options are explored, so it's possible to use unbounded iterators.

See also [`Choice`](@ref).
"""
choose(options,
       back::Union{Choice,Nothing} =
	 get(task_local_storage(), :previous_choice, nothing)) =
  Choice(options, back, identity)

"""
    choose(options...)

Make a Choice among the given options, backtracking to the previous Choice made
in this Task, if any.

In this form, the options are given individually in the call, and there must be
at least two of them.

See also [`Choice`](@ref).
"""
choose(first_option, second_option, rest_of_options...) =
  choose((first_option, second_option, rest_of_options...))

"""
    choice |> function

Chain the given function onto the successful results of the given Choice. This
is slightly different from the usual meaning of |> in Julia, since the function
receives a result of the Choice, not the Choice itself, and the value of the
whole expression is another Choice, not the result of calling the function.

See also [`Choice`](@ref).
"""
function Base.:|>(x::Choice, f::Function)
  old_receive = x.receive # capture just the old receive function, not x
  return Choice(x.options, x.back, input -> (old_receive(input) |> f))
end

struct Failed <: Exception
end

"""
    fail()

Throw a Choices.Failed exception to indicate that the option currently being
considered won't work. Triggers backtracking while there are other options to
consider.

See also [`Choice`](@ref).
"""
fail() = throw(Failed())

"""
    cut()

Commit to any choices already made, preventing backtracking past this point.

See also [`Choice`](@ref).
"""
cut() = task_local_storage(:previous_choice, nothing)

# TODO mark(), make it so that a subsequent cut()-fail() sequence backtracks back to the marked point (skipping the region of the computation between mark() and cut())

"""
    Choices.IterationState

Track the state of iteration over successful results of a nondeterministic
computation.

See also [`Choice`](@ref).
"""
struct IterationState
  # the iteration state we should backtrack to (if any) if we run out of options
  back::Union{IterationState,Nothing}
  # the choice whose options we're currently iterating over
  currentChoice::Choice
  # the iteration state of that choice's options
  optionsState
end

Base.IteratorSize(::Type{Choice{T}}) where {T} = Base.SizeUnknown()
Base.IteratorEltype(::Type{Choice{T}}) where {T} = Base.EltypeUnknown()

Base.iterate(iter::Choice) =
  iterate(iter, IterationState(nothing, iter, nothing))

"""
    iterate(iter::Choice[, state::IterationState])

Iterate over successful results of the nondeterministic computation represented by x.

See also [`Choice`](@ref).
"""
function Base.iterate(x::Choice, state::IterationState)
  # basically this is "for opt ∈ state.currentChoice.options", except we expose
  # the iteration state of the options iterator as optionsState, and resume
  # from state.optionsState
  currentChoice = state.currentChoice
  optionsState = state.optionsState
  iterateResult =
    (isnothing(optionsState) ? iterate(currentChoice.options) :
	iterate(currentChoice.options, optionsState))
  while (!isnothing(iterateResult))
    opt, optionsState = iterateResult
    @debug "considering option" opt
    try
      # try executing the receive function on the option
      result = currentChoice.receive(opt)
      @debug "got result" result
      # it succeeded!
      # prepare the next iteration state on this choice
      nextStateHere = IterationState(state.back, currentChoice, optionsState)
      if (isa(result, Choice)) # if the function returned another Choice, recur
	@debug "recursing..."
	return iterate(x, IterationState(nextStateHere, result, nothing))
      else # otherwise, just return the result with the next state
	@debug "returning!"
	return (result, nextStateHere)
      end
    catch ex
      if (!isa(ex, Failed))
	rethrow(ex)
      end # else move on to the next option for this Choice
    end
    @debug "iterating to next option"
    iterateResult =
      (isnothing(optionsState) ? iterate(currentChoice.options) :
	  iterate(currentChoice.options, optionsState))
  end
  # if we get here, we have exhausted the options for this Choice
  @debug "exhausted options" currentChoice.options
  if (isnothing(state.back)) # we can't backtrack anymore
    @debug "exhausted all options!"
    return nothing
  else # backtrack
    @debug "backtracking..."
    return iterate(x, state.back)
  end
end

end # module
