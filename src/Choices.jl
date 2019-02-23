module Choices

# choice.jl - as close as we can get to McCarthy's amb operator in Julia
# William de Beaumont
# 2019-02-23

# FIXME:
# - rosettacode-amb test fails
# - it would be nice if this whole thing were less stateful
#  - Choice.options shouldn't be depleted, rather indexed by a separate iteration state struct
#  - Choice.receive shouldn't be a Ref{Function}, rather we should make it a bare Function and create a new Choice with the composed function in |> (and set the new one in tls)
# - Choice.options ought to be an iterable thing, instead of getting all the options up front so we can put them in an array (though what does that do to the signature of choose()?)

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
"""
struct Choice{T}
  # the Choice we should backtrack to (if any) if we run out of options
  back::Union{Choice,Nothing}
  # the options for this choice that we haven't tried yet
  options::Array{T,1}
  # the function to pass the next option to
  receive::Ref{Function}
end

Base.show(io::IO, x::Choice) =
  print(io, "choose(", join(map(string, x.options), ", "), ")")

struct ChoiceFailed <: Exception
end

"""
    fail()

Throw a ChoiceFailed exception to indicate that the option currently being
considered won't work. Triggers backtracking while there are other options to
consider.

See also [`Choice`](@ref).
"""
fail() = throw(ChoiceFailed())

Base.IteratorSize(::Type{Choice{T}}) where {T} = Base.SizeUnknown()
Base.IteratorEltype(::Type{Choice{T}}) where {T} = Base.EltypeUnknown()

Base.iterate(iter::Choice, state::Choice) = iterate(state)

"""
    iterate(x::Choice)

Iterate over successful results of the nondeterministic computation represented by x. Note that this will only work one time through the collection of results.

See also [`Choice`](@ref).
"""
function Base.iterate(x::Choice)
  while (!isempty(x.options))
    try
      opt = popfirst!(x.options)
      println(stderr, "considering option ", opt)
      result = x.receive[](opt)
      state = x
      while (isa(result, Choice))
	state = result
	result = result[]
      end
      return (result, state)
    catch ex
      if (!isa(ex, ChoiceFailed))
	rethrow(ex)
      end
    end
  end
  if (isnothing(x.back))
    return nothing
  else
    return iterate(x.back)
  end
end

"""
    getindex(x::Choice)
    x[]

Get the next successful result of the nondeterministic computation represented
by x, or throw ChoiceFailed if there are no more.

See also [`Choice`](@ref).
"""
function Base.getindex(x::Choice)
  i = iterate(x)
  isnothing(i) && fail()
  return first(i)
end

"""
    choose(back::Choice, options...)

Make a Choice among the given options, backtracking to the given Choice if
those options run out.

See also [`Choice`](@ref).
"""
function choose(back::Union{Choice,Nothing}, options::T...) where {T}
  c = Choice(back, T[options...], Ref{Function}(identity))
  task_local_storage(:previous_choice, c)
  return c
end

"""
    choose(options...)

Make a Choice among the given options, backtracking to the previous choice made
in this Task (if any) if those options run out.

See also [`Choice`](@ref).
"""
choose(options::T...) where {T} =
  choose(get(task_local_storage(), :previous_choice, nothing), options...)

"""
    choice |> function

Chain the given function onto the successful results of the given Choice. This
is slightly different from the usual meaning of |> in Julia, since the function
receives the result of the choice, not the choice itself. It also modifies the
choice itself, so that its results will be the results of calling the function
on what were previously its results.

See also [`Choice`](@ref).
"""
function Base.:|>(x::Choice, f::Function)
  #x.receive[] = f ∘ x.receive[]
  old_receive = x.receive[]
  x.receive[] = function(arg1)
    println(stderr, "received arg ", arg1)
    arg2 = old_receive(arg1)
    println(stderr, "old receive turned that into ", arg2)
    isa(arg2, Choice) && (arg2 = arg2[])
    println(stderr, "de-choicifying that turned it into ", arg2)
    arg3 = f(arg2)
    println(stderr, "new f turned that into ", arg3)
    return arg3
  end
  return x
end

"""
    cut()

Commit to any choices already made, preventing backtracking past this point.

See also [`Choice`](@ref).
"""
cut() = task_local_storage(:previous_choice, nothing)

end # module
