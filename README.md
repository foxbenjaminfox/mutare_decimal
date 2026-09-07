# mutare_decimal

Mutation-testing mutators for [Decimal](https://hexdocs.pm/decimal), built as a
plugin for [Mutare](https://hexdocs.pm/mutare).

Money and precision code is exactly where a wrong operation hides best: a `sub`
where an `add` belongs, a `lt?` that should be `lte?`, a rounding mode nobody
pinned. Mutare's built-in mutators see `Decimal.add(a, b)` as just another
remote call; this plugin knows the Decimal API and mints
*well-formed-but-wrong* Decimal programs — a swapped operation, a reversed
comparison, a dropped rounding refinement — so a **surviving** mutant points at
a precise assertion your suite is missing.

## Install

Add it (and Mutare) as dev/test dependencies:

```elixir
def deps do
  [
    {:mutare, "~> 0.1", only: [:dev, :test], runtime: false},
    {:mutare_decimal, "~> 0.1", only: [:dev, :test], runtime: false}
  ]
end
```

(Decimal itself is **not** a dependency of this plugin — the mutators match
calls purely syntactically. Your own project already supplies Decimal.)

## Enable

List the families in `.mutare.exs`, alongside Mutare's built-ins:

```elixir
# .mutare.exs
[mutators: [:builtins] ++ Mutare.Decimal.all()]
```

`:builtins` keeps Mutare's default families and *adds* the Decimal ones; each
records under its own report family, and any can be enabled on its own:

```elixir
[mutators: [:builtins, Mutare.Decimal.Comparison]]   # just the comparison swaps
```

Then run Mutare as usual:

```
mix mutare
```

## The families

`Mutare.Decimal.all/0` returns eleven mutator families:

| Family | Name | Mutation |
| --- | --- | --- |
| `Mutare.Decimal.Arithmetic` | `:decimal_arithmetic` | swaps same-arity arithmetic calls (`add`/`sub`/`mult`/`div`/`div_int`/`rem`) and reverses visible operands of the non-commutative ones |
| `Mutare.Decimal.Comparison` | `:decimal_comparison` | swaps comparison predicates (`gt?`/`gte?`/`lt?`/`lte?`), swaps `min`/`max`, and reverses operands of `compare/2,3` and the deprecated `cmp/2` |
| `Mutare.Decimal.Classification` | `:decimal_classification` | swaps classification predicates (`positive?` ↔ `negative?`, `nan?` ↔ `inf?`) |
| `Mutare.Decimal.ZeroBoundary` | `:decimal_zero_boundary` | replaces `positive?`/`negative?` with the inclusive zero-boundary comparison (`gte?`/`lte?` against zero) — the off-by-the-boundary question |
| `Mutare.Decimal.Sign` | `:decimal_sign` | swaps `abs/1` ↔ `negate/1` and flips literal signs in `Decimal.new/3` |
| `Mutare.Decimal.DivRem` | `:decimal_div_rem` | rebuilds `div_rem/2` with the quotient/remainder pair in the wrong tuple order |
| `Mutare.Decimal.Transform` | `:decimal_transform` | removes value-transforming calls (`normalize`, `apply_context`, `abs`, `negate`, `sqrt`, `round/1,2,3`), collapsing to the argument |
| `Mutare.Decimal.ModeSwap` | `:decimal_mode_swap` | swaps `round/3` rounding modes and `to_string/2,3` output formats for a valid sibling |
| `Mutare.Decimal.DefaultDrop` | `:decimal_default_drop` | drops refinement/default arguments (`round/2,3`, `compare/3`, `eq?/3`), falling back to Decimal's defaults |
| `Mutare.Decimal.LimitsDrop` | `:decimal_limits_drop` | drops parsing/rendering limit arguments (`parse/2`, `cast/2`, `new/2`, `to_string/2,3`) |
| `Mutare.Decimal.Context` | `:decimal_context` | removes `Decimal.Context.with/set/update` effects |

Calls match written qualified (`Decimal.add(a, b)`), aliased, imported, or as a
pipe stage. Every replacement is itself a valid Decimal call, so a survivor
means a genuine missing assertion rather than a crash — and the families carry
**ownership splits** (with each other *and* with Mutare's built-ins) so no two
families mint the same mutant: a swap whose result another family's drop — or a
core literal mutation — already produces is excluded. The split rules live in
each family's moduledoc.

## Ignoring one kind of mutant

Every family declares ignore-variant labels — the target operation, target
mode, dropped argument, or operation kind — so a `# mutare:ignore[family:label]`
directive can suppress one kind of mutant without silencing the family:

```elixir
Decimal.mult(price, tax)          # mutare:ignore[decimal_arithmetic:div]
Decimal.compare(left, right)      # mutare:ignore[decimal_comparison:operands]
Decimal.parse(input, opts)        # mutare:ignore[decimal_limits_drop:parse_options]
Decimal.round(total, 2, :half_up) # mutare:ignore[decimal_mode_swap:half_even]
Decimal.positive?(amount)         # mutare:ignore[decimal_zero_boundary:gte?]
Decimal.normalize(amount)         # mutare:ignore[decimal_transform:normalize]
Decimal.negate(amount)            # mutare:ignore[decimal_sign:abs]
Decimal.Context.set(context)      # mutare:ignore[decimal_context:set]
```

A bare `# mutare:ignore[decimal_arithmetic]` suppresses the whole family on
that line. See `Mutare.Ignore` for the directive grammar.

## Supported versions

Decimal `>= 2.2.0 and < 4.0.0`. Matching is syntactic, so calls that only
exist in one line (e.g. `to_string/3`) simply never occur in codebases on the
other — every call the mutators *emit* exists across the whole range.

## Development

```
mix deps.get
mix test          # unit diffs + cross-family ownership + variant-label contract
mix check         # format + credo + dialyzer
```

## License

MIT — see [LICENSE](LICENSE).
