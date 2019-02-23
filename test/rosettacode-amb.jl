using Choices
using Test

# An implementation of this Rosetta Code task:
# http://rosettacode.org/wiki/Amb
function amb_test()
  # the word lattice to traverse
  lattice = [
    ["the", "that", "a"],
    ["frog", "elephant", "thing"],
    ["walked", "treaded", "grows"],
    ["slowly", "quickly"]
  ]
  # the constraint on adjacent words
  words_meet(before, after) = (isempty(before) || before[end] == after[1])
  # build the nondeterministic computation
  comp = choose([])
  for options ∈ lattice
    println(stderr, "adding options ", options)
    comp =
      (comp |> (before -> begin
        println(stderr, "got before = ", before)
	(choose(options...) |> (after ->
	begin
	  println(stderr, "got after = ", after)
	  isempty(before) || words_meet(before[end], after) || fail()
	  return [before; after]
	end))
      end))
    println(stderr, "comp is now ", comp)
  end
  println(stderr, "adding join operation")
  comp = (comp |> (words -> join(words, " ")))
  println(stderr, "comp is finally ", comp);
  # get all the possible answers
  return [comp...]
end
# test that we got the right answer only
@test amb_test() == ["that thing grows slowly"]
