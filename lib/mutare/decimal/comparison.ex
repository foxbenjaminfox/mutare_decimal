defmodule Mutare.Decimal.Comparison do
  @moduledoc """
  :decimal_comparison — swaps Decimal comparison calls.

  The predicate swaps mirror relational-operator boundary, direction, and complement mutants:

      Decimal.gt?(a, b)  # -> Decimal.gte?(a, b) / Decimal.lt?(a, b) / Decimal.lte?(a, b)
      Decimal.gte?(a, b) # -> Decimal.gt?(a, b) / Decimal.lte?(a, b) / Decimal.lt?(a, b)
      Decimal.lt?(a, b)  # -> Decimal.lte?(a, b) / Decimal.gt?(a, b) / Decimal.gte?(a, b)
      Decimal.lte?(a, b) # -> Decimal.lt?(a, b) / Decimal.gte?(a, b) / Decimal.gt?(a, b)

  Decimal.eq?/2 and Decimal.equal?/2 mutate to strict ordering predicates, min/2 and max/2
  swap, and compare/2, compare/3, and deprecated cmp/2 reverse their first two operands when
  both operands are visible in the call node and written differently (reversing identical
  operands would re-render the original program).
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @call_swaps %{
    {:gt?, 2} => [:gte?, :lt?, :lte?],
    {:gte?, 2} => [:gt?, :lte?, :lt?],
    {:lt?, 2} => [:lte?, :gt?, :gte?],
    {:lte?, 2} => [:lt?, :gte?, :gt?],
    {:eq?, 2} => [:gt?, :lt?],
    {:equal?, 2} => [:gt?, :lt?],
    {:max, 2} => [:min],
    {:min, 2} => [:max]
  }

  @operand_reversal MapSet.new([{:compare, 2}, {:compare, 3}, {:cmp, 2}])

  @variants [:gte?, :lt?, :gt?, :lte?, :min, :max, :operands]

  @impl Mutare.Mutator
  @spec name() :: :decimal_comparison
  def name, do: :decimal_comparison

  @doc "The target-operation labels accepted by qualified mutare ignore directives."
  @impl Mutare.Mutator
  @spec variants() :: [atom()]
  def variants, do: @variants

  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutare.Mutator.mutation()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    case Calls.resolved_call(node) do
      {@decimal, fun, args, rebuild} ->
        rebuild = CallRebuild.decimal(node, fun, args, pipe_mode, rebuild)

        mutations =
          call_swaps(fun, args, pipe_mode, rebuild) ++
            operand_reversal(fun, args, pipe_mode, rebuild)

        if mutations == [], do: :skip, else: mutations

      _unmatched ->
        :skip
    end
  end

  defp call_swaps(fun, args, pipe_mode, rebuild) do
    arity = Mutator.effective_arity(args, pipe_mode)

    case Map.fetch(@call_swaps, {fun, arity}) do
      {:ok, siblings} ->
        Enum.map(siblings, fn sibling ->
          Mutation.tagged(rebuild.(sibling, args), sibling)
        end)

      :error ->
        []
    end
  end

  defp operand_reversal(fun, [left, right | rest], :unpiped, rebuild) do
    arity = 2 + length(rest)

    if MapSet.member?(@operand_reversal, {fun, arity}) and
         not CallRebuild.same_node?(left, right) do
      [Mutation.tagged(rebuild.(fun, [right, left | rest]), :operands)]
    else
      []
    end
  end

  defp operand_reversal(_fun, _args, _pipe_mode, _rebuild), do: []
end
