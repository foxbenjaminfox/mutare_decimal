defmodule Mutare.Decimal.Classification do
  @moduledoc """
  :decimal_classification — swaps same-arity Decimal classification predicates.

  The family keeps the original argument and swaps between related boolean predicates:

      Decimal.positive?(num) # -> Decimal.negative?(num)
      Decimal.negative?(num) # -> Decimal.positive?(num)
      Decimal.nan?(num)      # -> Decimal.inf?(num)
      Decimal.inf?(num)      # -> Decimal.nan?(num)

  It supports qualified, aliased, imported, and piped Decimal calls.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @swaps %{
    {:positive?, 1} => :negative?,
    {:negative?, 1} => :positive?,
    {:nan?, 1} => :inf?,
    {:inf?, 1} => :nan?
  }

  @variants [:negative?, :positive?, :inf?, :nan?]

  @impl Mutare.Mutator
  @spec name() :: :decimal_classification
  def name, do: :decimal_classification

  @doc "The target-predicate labels accepted by qualified mutare ignore directives."
  @impl Mutare.Mutator
  @spec variants() :: [atom()]
  def variants, do: @variants

  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutare.Mutator.mutation()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    with {@decimal, fun, args, rebuild} <- Calls.resolved_call(node),
         rebuild = CallRebuild.decimal(node, fun, args, pipe_mode, rebuild),
         arity = Mutator.effective_arity(args, pipe_mode),
         {:ok, replacement} <- Map.fetch(@swaps, {fun, arity}) do
      [Mutation.tagged(rebuild.(replacement, args), replacement)]
    else
      _unmatched -> :skip
    end
  end
end
