defmodule Mutare.Decimal.DivRemTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.DivRem

  @mutators [DivRem]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_div_rem)

  defp module_with(body) do
    """
    defmodule DecimalDivRemSample do
      #{body}
    end
    """
  end

  describe "div_rem tuple-order mutation" do
    test "Decimal.div_rem/2 becomes remainder then integer quotient" do
      assert diffs(module_with("def calc(a, b), do: Decimal.div_rem(a, b)")) ==
               [
                 {"Decimal.div_rem(a, b)", "{Decimal.rem(a, b), Decimal.div_int(a, b)}"}
               ]
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalDivRemAliasSample do
        alias Decimal, as: D
        def calc(a, b), do: D.div_rem(a, b)
      end
      """

      assert diffs(source) == [
               {"D.div_rem(a, b)", "{D.rem(a, b), D.div_int(a, b)}"}
             ]
    end

    test "an imported Decimal tuple replacement qualifies Kernel-overlapping calls" do
      source = """
      defmodule DecimalDivRemImportSample do
        import Decimal
        def calc(a, b), do: div_rem(a, b)
      end
      """

      assert diffs(source) == [
               {"div_rem(a, b)", "{Elixir.Decimal.rem(a, b), div_int(a, b)}"}
             ]
    end

    test "a piped call is skipped because the first operand is not visible" do
      assert diffs(module_with("def calc(a, b), do: a |> Decimal.div_rem(b)")) == []
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls and wrong arities" do
      assert diffs(module_with("def calc(a, b), do: Other.div_rem(a, b)")) == []
      assert diffs(module_with("def calc(a, b, c), do: Decimal.div_rem(a, b, c)")) == []
    end

    test "declares tuple-order variants" do
      assert DivRem.variants() == [:tuple_order]
    end

    test "tags the mutation by tuple order" do
      result =
        Mutare.transform_string(module_with("def calc(a, b), do: Decimal.div_rem(a, b)"),
          mutators: @mutators
        )

      assert Enum.map(result.mutants, & &1.variant) == [["tuple_order"]]
    end

    test "qualified ignore suppresses the tuple-order mutation" do
      result =
        Mutare.transform_string(
          module_with(
            "def calc(a, b), do: Decimal.div_rem(a, b) # mutare:ignore[decimal_div_rem:tuple_order]"
          ),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["tuple_order"]}] = result.mutants
    end

    test "every div_rem mutant compiles" do
      source = module_with("def calc(a, b), do: Decimal.div_rem(a, b)")

      assert_metamutant_compiles(source, @mutators)
    end

    test "imported div_rem mutants that overlap Kernel compile" do
      source = """
      defmodule DecimalDivRemImportedCompileSample do
        import Decimal
        def calc(a, b), do: div_rem(a, b)
      end
      """

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
