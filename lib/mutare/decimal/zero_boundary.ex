defmodule Mutare.Decimal.ZeroBoundary do
  @moduledoc """
  :decimal_zero_boundary — makes Decimal sign predicates inclusive of zero.

  The family broadens strict sign classification around zero:

      Decimal.positive?(num) # -> Decimal.gte?(num, 0)
      Decimal.negative?(num) # -> Decimal.lte?(num, 0)

  Piped calls keep the zero operand visible in the pipe stage:

      num |> Decimal.positive?() # -> num |> Decimal.gte?(0)
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @swaps %{
    {:positive?, 1} => :gte?,
    {:negative?, 1} => :lte?
  }

  @variants [:gte?, :lte?]

  @impl Mutare.Mutator
  @spec name() :: :decimal_zero_boundary
  def name, do: :decimal_zero_boundary

  @doc "The inclusive-comparison labels accepted by qualified mutare ignore directives."
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
      [Mutation.tagged(rebuild.(replacement, args ++ [AST.literal(0)]), replacement)]
    else
      _unmatched -> :skip
    end
  end
end
