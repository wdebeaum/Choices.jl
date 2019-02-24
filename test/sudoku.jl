using Choices
using Test

# from https://en.wikipedia.org/wiki/Sudoku
puzzle = [
  5 3 0 0 7 0 0 0 0;
  6 0 0 1 9 5 0 0 0;
  0 9 8 0 0 0 0 6 0;
  8 0 0 0 6 0 0 0 3;
  4 0 0 8 0 3 0 0 1;
  7 0 0 0 2 0 0 0 6;
  0 6 0 0 0 0 2 8 0;
  0 0 0 4 1 9 0 0 5;
  0 0 0 0 8 0 0 7 9;
]
solution = [
  5 3 4 6 7 8 9 1 2;
  6 7 2 1 9 5 3 4 8;
  1 9 8 3 4 2 5 6 7;
  8 5 9 7 6 1 4 2 3;
  4 2 6 8 5 3 7 9 1;
  7 1 3 9 2 4 8 5 6;
  9 6 1 5 3 7 2 8 4;
  2 8 7 4 1 9 6 3 5;
  3 4 5 2 8 6 1 7 9;
]

function block_is_consistent(block)
  have = fill(false, 9)
  for n ∈ block
    n == 0 && continue
    have[n] && return false
    have[n] = true
  end
  return true
end

"""
    cell_block(i, j)

Returns indices (a tuple of two ranges) for the 3×3 sudoku block containing the
cell at (i, j).
"""
cell_block(i, j) = map(x -> x .+ (1:3), trunc.(Int, ((i, j) .- 1) ./ 3) .* 3)

cell_is_consistent(p, i, j) =
  block_is_consistent(p[i,1:9]) &&
  block_is_consistent(p[1:9,j]) &&
  block_is_consistent(p[cell_block(i,j)...])

iscomplete(p) = !any(n == 0 for n ∈ p)

function solve(p)
  # start with the unsolved puzzle
  comp = choose([p])
  # for each "blank" (zero) cell
  for k ∈ keys(p)
    if (p[k] == 0)
      # add a piece of the computation that makes a guess for that cell and
      # checks it
      comp =
	comp |> before ->
	  choose(1:9) |> function(guess)
	    after = copy(before) # super inefficient, but whatever, it's a test
	    after[k] = guess
	    cell_is_consistent(after, Tuple(k)...) || fail()
	    return after
	  end
    end
  end
  s = first(comp)
  cut()
  return s
end

@test solve(puzzle) == solution
