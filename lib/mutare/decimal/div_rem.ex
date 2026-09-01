defmodule Mutare.Decimal.DivRem do
  @moduledoc """
  :decimal_div_rem — swaps the quotient/remainder positions produced from Decimal.div_rem/2.

  The family replaces Decimal.div_rem/2 with the equivalent pair in the wrong order:

      Decimal.div_rem(left, right)
      # -> {Decimal.rem(left, right), Decimal.div_int(left, right)}

  Piped calls are skipped because the first operand is not visible in the call node.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @variants [:tuple_order]

  @impl Mutare.Mutator
  @spec name() :: :decimal_div_rem
  def name, do: :decimal_div_rem

  @doc "The tuple-position labels accepted by qualified mutare ignore directives."
  @impl Mutare.Mutator
  @spec variants() :: [atom()]
  def variants, do: @variants

  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutare.Mutator.mutation()]
  def mutate(node, %{pipe_mode: :unpiped}) do
    case Calls.resolved_call(node) do
      {@decimal, :div_rem, [left, right], rebuild} ->
        rebuild = CallRebuild.decimal(node, :div_rem, [left, right], :unpiped, rebuild)

        replacement =
          {:{}, [], [rebuild.(:rem, [left, right]), rebuild.(:div_int, [left, right])]}

        [Mutation.tagged(replacement, :tuple_order)]

      _unmatched ->
        :skip
    end
  end

  def mutate(_node, %{pipe_mode: :piped}), do: :skip
end
