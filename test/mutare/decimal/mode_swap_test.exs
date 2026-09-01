defmodule Mutare.Decimal.ModeSwapTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.ModeSwap

  @mutators [ModeSwap]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_mode_swap)

  defp module_with(body) do
    """
    defmodule DecimalModeSwapSample do
      #{body}
    end
    """
  end

  describe "rounding mode swaps" do
    test "Decimal.round/3 swaps half modes" do
      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :half_up)")) ==
               [
                 {"Decimal.round(a, places, :half_up)", "Decimal.round(a, places, :half_down)"},
                 {"Decimal.round(a, places, :half_up)", "Decimal.round(a, places, :half_even)"}
               ]
    end

    test "Decimal.round/3 swaps directional modes" do
      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :ceiling)")) ==
               [{"Decimal.round(a, places, :ceiling)", "Decimal.round(a, places, :floor)"}]

      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :up)")) ==
               [{"Decimal.round(a, places, :up)", "Decimal.round(a, places, :down)"}]
    end

    test "Decimal.round/3 never swaps to :half_up, which DefaultDrop's mode drop owns" do
      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :half_even)")) ==
               [
                 {"Decimal.round(a, places, :half_even)", "Decimal.round(a, places, :half_down)"}
               ]

      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :half_down)")) ==
               [
                 {"Decimal.round(a, places, :half_down)", "Decimal.round(a, places, :half_even)"}
               ]
    end
  end

  describe "to_string format swaps" do
    test "Decimal.to_string/2 swaps output formats, leaving :scientific to LimitsDrop's drop" do
      assert diffs(module_with("def render(a), do: Decimal.to_string(a, :normal)")) ==
               [
                 {"Decimal.to_string(a, :normal)", "Decimal.to_string(a, :xsd)"},
                 {"Decimal.to_string(a, :normal)", "Decimal.to_string(a, :raw)"}
               ]
    end

    test "Decimal.to_string/3 keeps options while swapping format" do
      assert diffs(
               module_with(
                 "def render(a), do: Decimal.to_string(a, :scientific, max_digits: :infinity)"
               )
             ) == [
               {"Decimal.to_string(a, :scientific, max_digits: :infinity)",
                "Decimal.to_string(a, :normal, max_digits: :infinity)"},
               {"Decimal.to_string(a, :scientific, max_digits: :infinity)",
                "Decimal.to_string(a, :xsd, max_digits: :infinity)"},
               {"Decimal.to_string(a, :scientific, max_digits: :infinity)",
                "Decimal.to_string(a, :raw, max_digits: :infinity)"}
             ]
    end

    test "Decimal.to_string/3 keeps :scientific as a target because its format has no drop twin" do
      assert diffs(
               module_with("def render(a), do: Decimal.to_string(a, :normal, max_digits: 10)")
             ) == [
               {"Decimal.to_string(a, :normal, max_digits: 10)",
                "Decimal.to_string(a, :scientific, max_digits: 10)"},
               {"Decimal.to_string(a, :normal, max_digits: 10)",
                "Decimal.to_string(a, :xsd, max_digits: 10)"},
               {"Decimal.to_string(a, :normal, max_digits: 10)",
                "Decimal.to_string(a, :raw, max_digits: 10)"}
             ]
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalModeSwapAliasSample do
        alias Decimal, as: D
        def calc(a, places), do: D.round(a, places, :floor)
      end
      """

      assert diffs(source) == [{"D.round(a, places, :floor)", "D.round(a, places, :ceiling)"}]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalModeSwapImportSample do
        import Decimal
        def calc(a, places), do: round(a, places, :down)
      end
      """

      assert diffs(source) == [{"round(a, places, :down)", "round(a, places, :up)"}]
    end

    test "a piped call mutates the visible mode argument" do
      source = module_with("def render(a), do: a |> Decimal.to_string(:normal)")

      assert diffs(source) == [
               {"Decimal.to_string(:normal)", "Decimal.to_string(:xsd)"},
               {"Decimal.to_string(:normal)", "Decimal.to_string(:raw)"}
             ]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls, wrong arities, variables, and unknown modes" do
      assert diffs(module_with("def calc(a, places), do: Other.round(a, places, :floor)")) == []
      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places)")) == []

      assert diffs(module_with("def calc(a, places, mode), do: Decimal.round(a, places, mode)")) ==
               []

      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :unknown)")) ==
               []
    end

    test "declares target-mode variants, without the drop-owned :half_up" do
      assert ModeSwap.variants() == [
               :down,
               :half_even,
               :ceiling,
               :floor,
               :half_down,
               :up,
               :scientific,
               :normal,
               :xsd,
               :raw
             ]
    end

    test "tags each mutation by the mode it becomes" do
      result =
        Mutare.transform_string(
          module_with("def calc(a, places), do: Decimal.round(a, places, :half_up)"),
          mutators: @mutators
        )

      assert Enum.map(result.mutants, & &1.variant) == [["half_down"], ["half_even"]]
    end

    test "qualified ignore suppresses only that target mode" do
      result =
        Mutare.transform_string(
          module_with(
            "def calc(a, places), do: Decimal.round(a, places, :half_up) # mutare:ignore[decimal_mode_swap:half_even]"
          ),
          mutators: @mutators
        )

      ignored_by_variant = Map.new(result.mutants, &{&1.variant, &1.ignored})

      assert ignored_by_variant[["half_down"]] == false
      assert ignored_by_variant[["half_even"]] == true
    end

    test "every mode-swap mutant compiles" do
      source =
        module_with("""
        def calc(a, places) do
          Decimal.round(a, places, :half_up)
          Decimal.round(a, places, :ceiling)
          Decimal.to_string(a, :normal, max_digits: :infinity)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
