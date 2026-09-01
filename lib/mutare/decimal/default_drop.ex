defmodule Mutare.Decimal.DefaultDrop do
  @moduledoc """
  :decimal_default_drop — drops Decimal arguments that refine a default behavior.

  The family removes explicit Decimal refinement arguments so the call falls back to the
  narrower/default operation:

      Decimal.round(num, places)       # -> Decimal.round(num)
      Decimal.round(num, places, mode) # -> Decimal.round(num, places)
      Decimal.compare(left, right, threshold) # -> Decimal.compare(left, right)
      Decimal.eq?(left, right, threshold)     # -> Decimal.eq?(left, right)

  It skips literal arguments that are equivalent to the implicit behavior: zero places,
  half-up rounding, and literal zero thresholds.

  Ownership split with the numeric literal families: a literal-number places or threshold is
  left alone entirely, not just when it equals the default. Core's integer/float literal
  families already perturb such a literal, and their zero mutant is this drop's semantic twin
  (round/2's default places is 0, and a zero threshold makes compare/3 behave as compare/2) —
  dropping the argument as well would mint the same mutant twice. The drop fires when the
  refinement is a dynamic expression those families cannot reach. The round/3 mode drop's twin
  on Mutare.Decimal.ModeSwap's side is handled there (it never swaps to :half_up).
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @rules %{
    {:round, 2} => {:places, :literal_number},
    {:round, 3} => {:rounding, {:literal_in, [:half_up]}},
    {:compare, 3} => {:threshold, :number_or_zero_string},
    {:eq?, 3} => {:threshold, :number_or_zero_string}
  }

  @variants [:places, :rounding, :threshold]

  @impl Mutare.Mutator
  @spec name() :: :decimal_default_drop
  def name, do: :decimal_default_drop

  @doc "The dropped-argument labels accepted by qualified mutare ignore directives."
  @impl Mutare.Mutator
  @spec variants() :: [atom()]
  def variants, do: @variants

  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutare.Mutator.mutation()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    with {@decimal, fun, args, rebuild} <- Calls.resolved_call(node),
         rebuild = CallRebuild.decimal(node, fun, args, pipe_mode, rebuild),
         arity = Mutator.effective_arity(args, pipe_mode),
         {:ok, {variant, skip_kind}} <- Map.fetch(@rules, {fun, arity}),
         {dropped, kept} <- List.pop_at(args, -1),
         false <- skip_dropped?(dropped, skip_kind) do
      [Mutation.tagged(rebuild.(fun, kept), variant)]
    else
      _unmatched -> :skip
    end
  end

  # Owned by the numeric literal families (see the ownership split in the moduledoc).
  defp skip_dropped?(node, :literal_number), do: literal_number?(node)

  defp skip_dropped?(node, {:literal_in, equivalent_defaults}) do
    case AST.literal_value(node) do
      {:ok, value} -> value in equivalent_defaults
      :error -> false
    end
  end

  defp skip_dropped?(node, :number_or_zero_string) do
    case AST.literal_value(node) do
      {:ok, value} when is_binary(value) -> decimal_zero_string?(value)
      _other -> literal_number?(node)
    end
  end

  # A plain or negated numeric literal (`2`, `-2`).
  defp literal_number?({:-, _meta, [inner]}), do: literal_number?(inner)

  defp literal_number?(node) do
    match?({:ok, value} when is_number(value), AST.literal_value(node))
  end

  defp decimal_zero_string?(value) do
    value
    |> String.trim()
    |> then(&Regex.match?(~r/^[+-]?(?:(?:0+)(?:\.0*)?|\.0+)(?:[eE][+-]?\d+)?$/, &1))
  end
end
