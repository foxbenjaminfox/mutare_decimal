# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-07

Initial release.

### Added

- Eleven mutator families over the Decimal call surface, each reported under
  its own name and independently enable-able:
  - `Mutare.Decimal.Arithmetic` (`:decimal_arithmetic`) — swaps same-arity
    arithmetic calls (`add`/`sub`/`mult`/`div`/`div_int`/`rem`) and reverses
    visible operands of the non-commutative ones.
  - `Mutare.Decimal.Comparison` (`:decimal_comparison`) — swaps comparison
    predicates (`gt?`/`gte?`/`lt?`/`lte?`), `min`/`max`, and reverses operands
    of `compare/2,3` and the deprecated `cmp/2`.
  - `Mutare.Decimal.Classification` (`:decimal_classification`) — swaps
    classification predicates (`positive?` ↔ `negative?`, `nan?` ↔ `inf?`).
  - `Mutare.Decimal.ZeroBoundary` (`:decimal_zero_boundary`) — replaces
    `positive?`/`negative?` with inclusive zero-boundary comparisons.
  - `Mutare.Decimal.Sign` (`:decimal_sign`) — swaps `abs/1` ↔ `negate/1` and
    flips literal signs in `Decimal.new/3`.
  - `Mutare.Decimal.DivRem` (`:decimal_div_rem`) — rebuilds `div_rem/2` with
    the quotient/remainder pair in the wrong tuple order.
  - `Mutare.Decimal.Transform` (`:decimal_transform`) — removes
    value-transforming calls (`normalize`, `apply_context`, `abs`, `negate`,
    `sqrt`, `round/1,2,3`).
  - `Mutare.Decimal.ModeSwap` (`:decimal_mode_swap`) — swaps `round/3`
    rounding modes and `to_string/2,3` output formats.
  - `Mutare.Decimal.DefaultDrop` (`:decimal_default_drop`) — drops
    refinement/default arguments (`round/2,3`, `compare/3`, `eq?/3`).
  - `Mutare.Decimal.LimitsDrop` (`:decimal_limits_drop`) — drops
    parsing/rendering limit arguments (`parse/2`, `cast/2`, `new/2`,
    `to_string/2,3`).
  - `Mutare.Decimal.Context` (`:decimal_context`) — removes
    `Decimal.Context.with/set/update` effects.
- Calls match written qualified, aliased, imported, or as a pipe stage.
- Ignore-variant labels on every mutation (target operation, mode, dropped
  argument, or operation kind), so `# mutare:ignore[family:label]` can
  suppress a single variant.
- `Mutare.Decimal.all/0` for splicing all families into a `:mutators` list.

Supports Decimal `>= 2.2.0 and < 4.0.0`.

[Unreleased]: https://github.com/foxbenjaminfox/mutare_decimal/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/foxbenjaminfox/mutare_decimal/releases/tag/v0.1.0
