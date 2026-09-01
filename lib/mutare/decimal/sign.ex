defmodule Mutare.Decimal.Sign do
  @moduledoc """
  :decimal_sign — swaps Decimal sign operations and constructor signs.

  The family changes sign-oriented Decimal calls:

      Decimal.abs(num)    # -> Decimal.negate(num)
      Decimal.negate(num) # -> Decimal.abs(num)

  It also flips literal signs in Decimal.new/3 constructors:

      Decimal.new(1, coef, exp)  # -> Decimal.new(-1, coef, exp)
      Decimal.new(-1, coef, exp) # -> Decimal.new(1, coef, exp)
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @call_swaps %{
    {:abs, 1} => :negate,
    {:negate, 1} => :abs
  }

  @variants [:negate, :abs, :negative, :positive]

  @impl Mutare.Mutator
  @spec name() :: :decimal_sign
  def name, do: :decimal_sign

  @doc "The target sign/function labels accepted by qualified mutare ignore directives."
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
          call_swap(fun, args, pipe_mode, rebuild) ++
            constructor_sign_flip(fun, args, pipe_mode, rebuild)

        if mutations == [], do: :skip, else: mutations

      _unmatched ->
        :skip
    end
  end

  defp call_swap(fun, args, pipe_mode, rebuild) do
    arity = Mutator.effective_arity(args, pipe_mode)

    case Map.fetch(@call_swaps, {fun, arity}) do
      {:ok, replacement} -> [Mutation.tagged(rebuild.(replacement, args), replacement)]
      :error -> []
    end
  end

  defp constructor_sign_flip(:new, [sign, coef, exp], :unpiped, rebuild) do
    case sign_literal(sign) do
      1 -> [Mutation.tagged(rebuild.(:new, [AST.literal(-1), coef, exp]), :negative)]
      -1 -> [Mutation.tagged(rebuild.(:new, [AST.literal(1), coef, exp]), :positive)]
      _other -> []
    end
  end

  defp constructor_sign_flip(_fun, _args, _pipe_mode, _rebuild), do: []

  defp sign_literal(node) do
    case AST.literal_value(node) do
      {:ok, 1} -> 1
      _other -> negative_one_literal(node)
    end
  end

  defp negative_one_literal({:-, _meta, [inner]}) do
    case AST.literal_value(inner) do
      {:ok, 1} -> -1
      _other -> nil
    end
  end

  defp negative_one_literal(_node), do: nil
end
