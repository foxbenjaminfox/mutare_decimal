defmodule Mutare.Decimal.Transform do
  @moduledoc """
  :decimal_transform — removes Decimal value-transforming calls.

  The family replaces a value-transforming Decimal call with its input, testing whether the
  transformation itself is observed:

      Decimal.normalize(num)        # -> num
      Decimal.apply_context(num)    # -> num
      Decimal.abs(num)              # -> num
      Decimal.negate(num)           # -> num
      Decimal.sqrt(num)             # -> num
      Decimal.round(num, places)    # -> num

  In a pipe stage, the call becomes Elixir.Function.identity/1 so the surrounding pipe remains
  compile-safe.
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @removable MapSet.new([
               {:abs, 1},
               {:negate, 1},
               {:sqrt, 1},
               {:normalize, 1},
               {:apply_context, 1},
               {:round, 1},
               {:round, 2},
               {:round, 3}
             ])

  @variants [:abs, :negate, :sqrt, :normalize, :apply_context, :round]

  @impl Mutare.Mutator
  @spec name() :: :decimal_transform
  def name, do: :decimal_transform

  @doc "The removed-function labels accepted by qualified mutare ignore directives."
  @impl Mutare.Mutator
  @spec variants() :: [atom()]
  def variants, do: @variants

  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutare.Mutator.mutation()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    with {@decimal, fun, args, _rebuild} <- Calls.resolved_call(node),
         arity = Mutator.effective_arity(args, pipe_mode),
         true <- MapSet.member?(@removable, {fun, arity}),
         [replacement] <- removed_call(pipe_mode, args) do
      [Mutation.tagged(replacement, fun)]
    else
      _unmatched -> :skip
    end
  end

  defp removed_call(:piped, _args), do: [AST.absolute_call([:Function], :identity, [])]
  defp removed_call(:unpiped, []), do: :skip
  defp removed_call(:unpiped, [first | _rest]), do: [first]
end
