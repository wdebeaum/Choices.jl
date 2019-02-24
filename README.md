[![Build Status](https://travis-ci.org/wdebeaum/Choices.jl.png)](https://travis-ci.org/wdebeaum/Choices.jl)
[![codecov.io](http://codecov.io/github/wdebeaum/Choices.jl/coverage.svg?branch=master)](http://codecov.io/github/wdebeaum/Choices.jl?branch=master)

# Choices

Support for nondeterministic programming in Julia, using iterable, backtracking
Choices and a special method of the |> operator for combining them with
(anonymous) functions (which stand in for continuations). This is as close as
we can get to McCarthy's amb operator in Julia, given that it doesn't have
call/cc or anything like it.

`choose(a,b,c,...)` sets up a nondeterministic computation that chooses among
options `a,b,c,...` by trying them in order. `choose(iter)` also works, even
when `iter` is unbounded.

`comp::Choice |> fn::Function` makes an extended computation that applies `fn`
to each option.

If `fn` calls `choose`, it extends the computation with another nondeterministic `Choice`.

If `fn` calls `fail()`, the computation backtracks to the last `Choice` that
still has unexplored options, and tries the next option. The iteration ends
when all options have been explored.

Calling `cut()` commits the current choices and prevents backtracking past that
point in the computation.

`Choice`s work well with existing Julia iteration mechanisms, e.g.
`first(comp::Choice)` will get the final value of the first successful path
through the computation; `[comp...]` will get all of them, `[take(comp,
10)...]` will get the first 10, etc.

It's a good idea to call `cut()` when you're done iterating a nondeterministic
computation, to avoid unintentional backtracking from later computations to
earlier ones.

Full, concrete examples can be seen under [test/](test).
