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
  comp = choose([[]])
  for options ∈ lattice
    comp =
      (comp |> (before -> begin
	(choose(options...) |> (after ->
	begin
	  isempty(before) || words_meet(before[end], after) || fail()
	  return [before; after]
	end))
      end))
  end
  comp = (comp |> (words -> join(words, " ")))
  # get all the possible answers
  answers = [comp...]
  cut()
  return answers
end
# test that we got the right answer only
@test amb_test() == ["that thing grows slowly"]
