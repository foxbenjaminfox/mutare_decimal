defmodule Mutare.Decimal.ModeSwap do
  @moduledoc """
  :decimal_mode_swap — swaps Decimal rounding and string-format mode atoms.

  The family targets mode arguments whose legal value set is Decimal-specific:

      Decimal.round(num, places, :half_up)     # -> :half_down / :half_even
      Decimal.round(num, places, :ceiling)     # -> :floor
      Decimal.round(num, places, :up)          # -> :down
      Decimal.to_string(num, :normal)          # -> :xsd / :raw
      Decimal.to_string(num, :scientific, opts) # -> :normal / :xsd / :raw

  Piped calls are supported when the mode argument is visible in the pipe stage.

  Ownership split with the drop families: where dropping the mode argument already yields the
  default-mode program — Mutare.Decimal.DefaultDrop drops round/3's mode (equivalent to
  :half_up) and Mutare.Decimal.LimitsDrop drops to_string/2's format (equivalent to
  :scientific) — this family does not also swap to that default, so the two never mint the
  same mutant. to_string/3's format has no drop twin (LimitsDrop drops its trailing options
  instead), so :scientific stays a swap target there. Because :half_up can then never be a
  swap target, it is not part of this family's variant vocabulary.
  """

  @behaviour Mutare.Mutator

  alias Mutare.AST
  alias Mutare.Calls
  alias Mutare.Decimal.CallRebuild
  alias Mutare.Mutator
  alias Mutare.Mutator.Mutation

  @decimal Calls.module_key(Decimal)

  @rounding_modes %{
    down: [:up],
    half_up: [:half_down, :half_even],
    half_even: [:half_up, :half_down],
    ceiling: [:floor],
    floor: [:ceiling],
    half_down: [:half_up, :half_even],
    up: [:down]
  }

  @string_formats %{
    scientific: [:normal, :xsd, :raw],
    normal: [:scientific, :xsd, :raw],
    xsd: [:scientific, :normal, :raw],
    raw: [:scientific, :normal, :xsd]
  }

  # The third element is the mode a sibling drop family's argument drop is equivalent to
  # (see the ownership split in the moduledoc): it is excluded as a swap target so the two
  # families never produce the same mutant. `nil` excludes nothing.
  @rules %{
    {:round, 3} => {2, @rounding_modes, :half_up},
    {:to_string, 2} => {1, @string_formats, :scientific},
    {:to_string, 3} => {1, @string_formats, nil}
  }

  @variants [:down, :half_even, :ceiling, :floor, :half_down, :up] ++
              [:scientific, :normal, :xsd, :raw]

  @impl Mutare.Mutator
  @spec name() :: :decimal_mode_swap
  def name, do: :decimal_mode_swap

  @doc "The target-mode labels accepted by qualified mutare ignore directives."
  @impl Mutare.Mutator
  @spec variants() :: [atom()]
  def variants, do: @variants

  @impl Mutare.Mutator
  @spec mutate(Macro.t(), Mutare.Mutator.context()) :: :skip | [Mutare.Mutator.mutation()]
  def mutate(node, %{pipe_mode: pipe_mode}) do
    with {@decimal, fun, args, rebuild} <- Calls.resolved_call(node),
         rebuild = CallRebuild.decimal(node, fun, args, pipe_mode, rebuild),
         arity = Mutator.effective_arity(args, pipe_mode),
         {:ok, {effective_position, mode_swaps, drop_covered}} <- Map.fetch(@rules, {fun, arity}),
         visible_position when is_integer(visible_position) <-
           Mutator.visible_index(effective_position, pipe_mode),
         mode_node when not is_nil(mode_node) <- Enum.at(args, visible_position),
         {:ok, mode} <- AST.literal_value(mode_node),
         {:ok, replacements} <- Map.fetch(mode_swaps, mode) do
      Enum.map(replacements -- [drop_covered], fn replacement ->
        mutated_args = List.replace_at(args, visible_position, AST.literal(replacement))

        Mutation.tagged(rebuild.(fun, mutated_args), replacement)
      end)
    else
      _unmatched -> :skip
    end
  end
end
