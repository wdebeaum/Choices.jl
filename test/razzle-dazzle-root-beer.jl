using Choices
using Test

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
actual = [get_both_parts()...]
cut()
expected = [("razzle", "dazzle"), ("root", "beer")]
@test actual == expected

