using Choices
using Test

function test_error_handling() # and show()
  ary = ["one", "two", "three"]
  comp = choose(1,2,5)
  @test repr(comp) == "(choose from (1, 2, 5))"
  comp = 
    comp |> the_number_of_the_counting ->
    ary[the_number_of_the_counting]
  @test repr(comp) == "(choose from (1, 2, 5) and call a nontrivial function)"
  @test_throws BoundsError [comp...] # 5 is right out!
  cut()
end
test_error_handling()

function test_loads_of_backtracking() # and @debug logs
  comp = choose([[0]])
  for n ∈ 1:5
    comp =
      comp |> ary ->
      choose(false, true) |> atend ->
      (atend ? [ary; n] : [n; ary])
  end
  comp =
    comp |> ary -> begin
      issorted(ary) || fail()
      ary
    end
  answers = []
  @test_logs (:debug, "considering option") (:debug, "got result") (:debug, "recursing...") (:debug, "returning!") (:debug, "iterating to next option") (:debug, "exhausted options") (:debug, "exhausted all options!") (:debug, "backtracking...") match_mode=:any min_level=Base.CoreLogging.Debug (answers = [comp...])
  cut()
  @test answers == [[0,1,2,3,4,5]]
end
test_loads_of_backtracking()
