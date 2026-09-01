defmodule Mutare.Decimal.CallRebuild do
  @moduledoc false

  alias Mutare.AST
  alias Mutare.Mutator

  @kernel_calls MapSet.new(Kernel.__info__(:functions) ++ Kernel.__info__(:macros))

  @type rebuild :: (atom(), [Macro.t()] -> Macro.t())

  @spec decimal(
          Macro.t(),
          atom(),
          [Macro.t()],
          Mutator.pipe_mode(),
          rebuild()
        ) :: rebuild()
  def decimal({fun, _meta, args}, original_fun, original_args, pipe_mode, rebuild)
      when is_atom(fun) and is_list(args) do
    fn new_fun, new_args ->
      if changed_call?(original_fun, original_args, new_fun, new_args, pipe_mode) and
           kernel_call?(new_fun, new_args, pipe_mode) do
        AST.absolute_call([:Decimal], new_fun, new_args)
      else
        rebuild.(new_fun, new_args)
      end
    end
  end

  def decimal(_node, _original_fun, _original_args, _pipe_mode, rebuild), do: rebuild

  defp changed_call?(original_fun, original_args, new_fun, new_args, pipe_mode) do
    new_fun != original_fun or
      Mutator.effective_arity(new_args, pipe_mode) !=
        Mutator.effective_arity(original_args, pipe_mode)
  end

  defp kernel_call?(fun, args, pipe_mode) do
    MapSet.member?(@kernel_calls, {fun, Mutator.effective_arity(args, pipe_mode)})
  end

  @doc false
  # Meta-insensitive structural equality, for skipping operand reversals whose
  # operands are the same written expression (the reversal re-renders the
  # original program).
  @spec same_node?(Macro.t(), Macro.t()) :: boolean()
  def same_node?(left, right), do: strip(left) == strip(right)

  defp strip(node) do
    Macro.prewalk(node, fn
      {form, meta, args} when is_list(meta) -> {form, [], args}
      other -> other
    end)
  end
end
