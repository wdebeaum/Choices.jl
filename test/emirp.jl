using Choices
using Test
using Base.Iterators: take, countfrom

# test iterating over the first few emirp numbers
# https://en.wikipedia.org/wiki/Emirp

# first some common definitions:
divides(x::Integer, y::Integer) = isinteger(x / y)
isprime(x::Integer) = !any(y -> divides(x, y), 2:trunc(Integer, √x))
reverse_digits(x::Int) = parse(Int, reverse(string(x)))

# the conventional way to do it with a Generator:
function isemirp(x::Int)
  isprime(x) || return false
  rev_x = reverse_digits(x)
  return (x != rev_x && isprime(rev_x))
end
generated_emirps = [take((x for x ∈ countfrom() if isemirp(x)), 10)...]

# a way to do it with Choices:
emirps_chooser =
  choose(countfrom()) |> x ->
  (isprime(x) ? reverse_digits(x) : fail()) |> rev_x ->
  ((x != rev_x && isprime(rev_x)) ? x : fail())
chosen_emirps = [take(emirps_chooser, 10)...]
cut()

expected_emirps = [13, 17, 31, 37, 71, 73, 79, 97, 107, 113]
@test generated_emirps == expected_emirps
@test chosen_emirps == expected_emirps
