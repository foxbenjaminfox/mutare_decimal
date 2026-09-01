defmodule Mutare.Decimal.Context do
  @moduledoc """
  :decimal_context — mutates Decimal.Context usage.

  The family removes or weakens context operations:

      Decimal.Context.with(context, fun) # -> fun.()
      Decimal.Context.set(context)       # -> :ok
      Decimal.Context.update(fun)        # -> :ok

  Piped context calls are skipped because replacing a pipe stage with a literal or a direct
  zero-arity function call would not be compile-safe.
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Mutator.Mutation

  @context Calls.module_key(Decimal.Context)

  @variants [:with, :set, :update]

  @impl Mutare.Mutator
  @spec name() :: :decimal_context
  def name, do: :decimal_context

  @doc "The context-operation labels accepted by qualified ignores."
  @impl Mutare.Mutator
  @spec variants() :: [atom()]
  def variants, do: @variants

  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutare.Mutator.mutation()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    mutations = context_call_mutations(node, pipe_mode)

    if mutations == [], do: :skip, else: mutations
  end

  defp context_call_mutations(node, :unpiped) do
    case Calls.resolved_call(node) do
      {@context, :with, [_context, fun], _rebuild} ->
        [Mutation.tagged(anonymous_call(fun), :with)]

      {@context, :set, [_context], _rebuild} ->
        [Mutation.tagged(AST.literal(:ok), :set)]

      {@context, :update, [_fun], _rebuild} ->
        [Mutation.tagged(AST.literal(:ok), :update)]

      _unmatched ->
        []
    end
  end

  defp context_call_mutations(_node, :piped), do: []

  defp anonymous_call(fun), do: {{:., [], [fun]}, [], []}
end
