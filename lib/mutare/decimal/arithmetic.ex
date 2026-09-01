defmodule Mutare.Decimal.Arithmetic do
  @moduledoc """
  :decimal_arithmetic — swaps Decimal arithmetic calls for same-arity siblings and
  reverses operands for non-commutative arithmetic calls.

  The family changes only the function name and keeps the original arguments:

      Decimal.add(a, b)     # -> Decimal.sub(a, b) / Decimal.mult(a, b)
      Decimal.sub(a, b)     # -> Decimal.add(a, b)
      Decimal.mult(a, b)    # -> Decimal.div(a, b)
      Decimal.div(a, b)     # -> Decimal.mult(a, b) / Decimal.div_int(a, b)
      Decimal.div_int(a, b) # -> Decimal.rem(a, b) / Decimal.div(a, b)
      Decimal.rem(a, b)     # -> Decimal.div_int(a, b)

  It also reverses operands for Decimal.sub/2, div/2, div_int/2, and rem/2 when both
  operands are visible and written differently:

      Decimal.sub(a, b) # -> Decimal.sub(b, a)

  It is pipe-aware and resolves qualified, aliased, and imported Decimal calls through Mutare's
  call resolver. Operand reversal is skipped for piped calls because the first operand is not
  present in the call node.
  """

  @behaviour Mutare.Mutator

  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @swaps %{
    {:add, 2} => [:sub, :mult],
    {:sub, 2} => [:add],
    {:mult, 2} => [:div],
    {:div, 2} => [:mult, :div_int],
    {:div_int, 2} => [:rem, :div],
    {:rem, 2} => [:div_int]
  }

  @operand_reversal MapSet.new([:sub, :div, :div_int, :rem])

  @variants [:sub, :mult, :add, :div, :rem, :div_int, :operands]

  @impl Mutare.Mutator
  @spec name() :: :decimal_arithmetic
  def name, do: :decimal_arithmetic

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

    case Map.fetch(@swaps, {fun, arity}) do
      {:ok, siblings} ->
        Enum.map(siblings, fn sibling ->
          Mutation.tagged(rebuild.(sibling, args), sibling)
        end)

      :error ->
        []
    end
  end

  defp operand_reversal(fun, [left, right], :unpiped, rebuild) do
    if MapSet.member?(@operand_reversal, fun) and not CallRebuild.same_node?(left, right) do
      [Mutation.tagged(rebuild.(fun, [right, left]), :operands)]
    else
      []
    end
  end

  defp operand_reversal(_fun, _args, _pipe_mode, _rebuild), do: []
end
