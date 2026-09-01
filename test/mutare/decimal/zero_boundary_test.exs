defmodule Mutare.Decimal.ZeroBoundaryTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.ZeroBoundary

  @mutators [ZeroBoundary]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_zero_boundary)

  defp module_with(body) do
    """
    defmodule DecimalZeroBoundarySample do
      #{body}
    end
    """
  end

  describe "zero-boundary predicate mutations" do
    test "Decimal.positive?/1 mutates to gte?/2 against zero" do
      assert diffs(module_with("def check(a), do: Decimal.positive?(a)")) ==
               [{"Decimal.positive?(a)", "Decimal.gte?(a, 0)"}]
    end

    test "Decimal.negative?/1 mutates to lte?/2 against zero" do
      assert diffs(module_with("def check(a), do: Decimal.negative?(a)")) ==
               [{"Decimal.negative?(a)", "Decimal.lte?(a, 0)"}]
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalZeroBoundaryAliasSample do
        alias Decimal, as: D
        def check(a), do: D.positive?(a)
      end
      """

      assert diffs(source) == [{"D.positive?(a)", "D.gte?(a, 0)"}]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalZeroBoundaryImportSample do
        import Decimal
        def check(a), do: negative?(a)
      end
      """

      assert diffs(source) == [{"negative?(a)", "lte?(a, 0)"}]
    end

    test "a piped call adds the zero as a visible argument" do
      source = module_with("def check(a), do: a |> Decimal.positive?()")

      assert diffs(source) == [{"Decimal.positive?()", "Decimal.gte?(0)"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls, wrong arities, and unrelated predicates" do
      assert diffs(module_with("def check(a), do: Other.positive?(a)")) == []
      assert diffs(module_with("def check(a, b), do: Decimal.positive?(a, b)")) == []
      assert diffs(module_with("def check(a), do: Decimal.nan?(a)")) == []
    end

    test "declares inclusive comparison variants" do
      assert ZeroBoundary.variants() == [:gte?, :lte?]
    end

    test "tags each mutation by the comparison it becomes" do
      source =
        module_with("""
        def positive(a), do: Decimal.positive?(a)
        def negative(a), do: Decimal.negative?(a)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [["gte?"], ["lte?"]]
    end

    test "qualified ignore suppresses only the requested zero-boundary variant" do
      result =
        Mutare.transform_string(
          module_with(
            "def check(a), do: Decimal.positive?(a) # mutare:ignore[decimal_zero_boundary:gte?]"
          ),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["gte?"]}] = result.mutants
    end

    test "every zero-boundary mutant compiles" do
      source =
        module_with("""
        def check(a) do
          Decimal.positive?(a) or Decimal.negative?(a)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
