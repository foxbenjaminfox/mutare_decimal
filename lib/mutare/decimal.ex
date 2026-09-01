defmodule Mutare.Decimal do
  @moduledoc """
  Mutation-testing mutators for Decimal calls.

  Use all/0 to enable every Decimal-specific family alongside Mutare's built-ins:

      # .mutare.exs
      [mutators: [:builtins] ++ Mutare.Decimal.all()]

  The families are:

    * Mutare.Decimal.Arithmetic — same-arity arithmetic call swaps, reported as
      :decimal_arithmetic.
    * Mutare.Decimal.Comparison — Decimal predicate/value comparison swaps and
      compare operand reversal, reported as :decimal_comparison.
    * Mutare.Decimal.DefaultDrop — Decimal default/refinement argument drops, reported as
      :decimal_default_drop.
    * Mutare.Decimal.LimitsDrop — Decimal parse/render limit argument drops, reported as
      :decimal_limits_drop.
    * Mutare.Decimal.ModeSwap — Decimal rounding and string-format mode swaps, reported as
      :decimal_mode_swap.
    * Mutare.Decimal.Classification — Decimal classification predicate swaps, reported as
      :decimal_classification.
    * Mutare.Decimal.ZeroBoundary — Decimal sign predicates broadened around zero, reported as
      :decimal_zero_boundary.
    * Mutare.Decimal.Transform — Decimal transform call removal, reported as
      :decimal_transform.
    * Mutare.Decimal.Sign — Decimal sign-operation and constructor-sign swaps, reported as
      :decimal_sign.
    * Mutare.Decimal.DivRem — Decimal.div_rem/2 tuple-order mutation, reported as
      :decimal_div_rem.
    * Mutare.Decimal.Context — Decimal.Context call mutations, reported as
      :decimal_context.

  The mutators match Decimal calls written qualified, aliased, imported, or as pipe stages.
  """

  @families [
    Mutare.Decimal.Arithmetic,
    Mutare.Decimal.Comparison,
    Mutare.Decimal.DefaultDrop,
    Mutare.Decimal.LimitsDrop,
    Mutare.Decimal.ModeSwap,
    Mutare.Decimal.Classification,
    Mutare.Decimal.ZeroBoundary,
    Mutare.Decimal.Transform,
    Mutare.Decimal.Sign,
    Mutare.Decimal.DivRem,
    Mutare.Decimal.Context
  ]

  @doc """
  Returns this package's mutator families.

      iex> Mutare.Decimal.all()
      [
        Mutare.Decimal.Arithmetic,
        Mutare.Decimal.Comparison,
        Mutare.Decimal.DefaultDrop,
        Mutare.Decimal.LimitsDrop,
        Mutare.Decimal.ModeSwap,
        Mutare.Decimal.Classification,
        Mutare.Decimal.ZeroBoundary,
        Mutare.Decimal.Transform,
        Mutare.Decimal.Sign,
        Mutare.Decimal.DivRem,
        Mutare.Decimal.Context
      ]
  """
  @spec all() :: [module()]
  def all, do: @families
end
