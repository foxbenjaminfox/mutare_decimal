defmodule Mutare.Decimal.LimitsDrop do
  @moduledoc """
  :decimal_limits_drop — drops explicit Decimal parsing/rendering limit arguments.

  The family removes trailing options or format arguments so calls use Decimal's default
  parsing and rendering limits:

      Decimal.parse(input, opts)        # -> Decimal.parse(input)
      Decimal.cast(input, opts)         # -> Decimal.cast(input)
      Decimal.new(input, opts)          # -> Decimal.new(input)
      Decimal.to_string(num, type, opts) # -> Decimal.to_string(num, type)
      Decimal.to_string(num, type)       # -> Decimal.to_string(num)

  Literal arguments equivalent to Decimal's defaults are skipped.

  The to_string/2 drop yields the default-format (:scientific) program, so it owns that
  mutant: Mutare.Decimal.ModeSwap never swaps a to_string/2 format to :scientific (see the
  ownership split in its moduledoc).
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @default_parse_max_digits 34
  @default_parse_max_exponent 6_144
  @default_to_string_max_digits 6_178

  @rules %{
    {:parse, 2} => {:parse_options, :parse_limits},
    {:cast, 2} => {:cast_options, :parse_limits},
    {:new, 2} => {:new_options, :parse_limits},
    {:to_string, 3} => {:to_string_options, :to_string_limits},
    {:to_string, 2} => {:string_format, :string_format}
  }

  @variants [:parse_options, :cast_options, :new_options, :to_string_options, :string_format]

  @impl Mutare.Mutator
  @spec name() :: :decimal_limits_drop
  def name, do: :decimal_limits_drop

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
         {:ok, {variant, default_kind}} <- Map.fetch(@rules, {fun, arity}),
         {dropped, kept} <- List.pop_at(args, -1),
         false <- equivalent_default?(dropped, default_kind) do
      [Mutation.tagged(rebuild.(fun, kept), variant)]
    else
      _unmatched -> :skip
    end
  end

  defp equivalent_default?(node, :string_format) do
    AST.literal_value(node) == {:ok, :scientific}
  end

  defp equivalent_default?(node, :parse_limits) do
    case literal_keyword(node) do
      {:ok, opts} -> parse_limits_equivalent?(opts)
      :error -> false
    end
  end

  defp equivalent_default?(node, :to_string_limits) do
    case literal_keyword(node) do
      {:ok, opts} -> to_string_limits_equivalent?(opts)
      :error -> false
    end
  end

  defp literal_keyword(node), do: node |> AST.unwrap_literal() |> literal_keyword_unwrapped()

  defp literal_keyword_unwrapped(opts) when is_list(opts) do
    if Enum.all?(opts, &match?({_key, _value}, &1)) do
      {:ok, opts}
    else
      :error
    end
  end

  defp literal_keyword_unwrapped(_node), do: :error

  defp parse_limits_equivalent?(opts) do
    Enum.reduce_while(
      opts,
      {:ok, %{max_digits: @default_parse_max_digits, max_exponent: @default_parse_max_exponent}},
      fn
        {key_node, value_node}, {:ok, limits} ->
          with key when key in [:max_digits, :max_exponent] <- AST.key_atom(key_node),
               {:ok, value} <- AST.literal_value(value_node),
               true <- valid_limit?(value) do
            {:cont, {:ok, Map.put(limits, key, value)}}
          else
            _ -> {:halt, :error}
          end
      end
    )
    |> case do
      {:ok, %{max_digits: @default_parse_max_digits, max_exponent: @default_parse_max_exponent}} ->
        true

      _other ->
        false
    end
  end

  defp to_string_limits_equivalent?(opts) do
    case first_literal_option(opts, :max_digits) do
      {:ok, value} -> value == @default_to_string_max_digits
      :missing -> true
      :error -> false
    end
  end

  defp first_literal_option(opts, key) do
    Enum.find_value(opts, :missing, &literal_option_value(&1, key))
  end

  defp literal_option_value({key_node, value_node}, key) do
    if AST.key_atom(key_node) == key, do: literal_option_value(value_node)
  end

  defp literal_option_value(_entry, _key), do: nil

  defp literal_option_value(value_node) do
    case AST.literal_value(value_node) do
      {:ok, value} -> {:ok, value}
      :error -> :error
    end
  end

  defp valid_limit?(value), do: value == :infinity or (is_integer(value) and value >= 0)
end
