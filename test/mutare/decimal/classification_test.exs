defmodule Mutare.Decimal.ClassificationTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.Classification

  @mutators [Classification]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_classification)

  defp module_with(body) do
    """
    defmodule DecimalClassificationSample do
      #{body}
    end
    """
  end

  describe "classification predicate swaps" do
    test "positive?/1 and negative?/1 swap" do
      assert diffs(module_with("def check(a), do: Decimal.positive?(a)")) ==
               [{"Decimal.positive?(a)", "Decimal.negative?(a)"}]

      assert diffs(module_with("def check(a), do: Decimal.negative?(a)")) ==
               [{"Decimal.negative?(a)", "Decimal.positive?(a)"}]
    end

    test "nan?/1 and inf?/1 swap" do
      assert diffs(module_with("def check(a), do: Decimal.nan?(a)")) ==
               [{"Decimal.nan?(a)", "Decimal.inf?(a)"}]

      assert diffs(module_with("def check(a), do: Decimal.inf?(a)")) ==
               [{"Decimal.inf?(a)", "Decimal.nan?(a)"}]
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalClassificationAliasSample do
        alias Decimal, as: D
        def check(a), do: D.positive?(a)
      end
      """

      assert diffs(source) == [{"D.positive?(a)", "D.negative?(a)"}]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalClassificationImportSample do
        import Decimal
        def check(a), do: positive?(a)
      end
      """

      assert diffs(source) == [{"positive?(a)", "negative?(a)"}]
    end

    test "a piped call uses effective arity and mutates the stage" do
      source = module_with("def check(a), do: a |> Decimal.positive?()")

      assert diffs(source) == [{"Decimal.positive?()", "Decimal.negative?()"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls and wrong arities" do
      assert diffs(module_with("def check(a), do: Other.positive?(a)")) == []
      assert diffs(module_with("def check(a, b), do: Decimal.positive?(a, b)")) == []
      assert diffs(module_with("def check(a), do: Decimal.integer?(a)")) == []
    end

    test "declares target-predicate variants" do
      assert Classification.variants() == [:negative?, :positive?, :inf?, :nan?]
    end

    test "tags each mutation by the predicate it becomes" do
      source =
        module_with("""
        def positive(a), do: Decimal.positive?(a)
        def nan(a), do: Decimal.nan?(a)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [["negative?"], ["inf?"]]
    end

    test "qualified ignore suppresses only that target predicate" do
      result =
        Mutare.transform_string(
          module_with(
            "def check(a), do: Decimal.positive?(a) # mutare:ignore[decimal_classification:negative?]"
          ),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["negative?"]}] = result.mutants
    end

    test "every classification mutant compiles" do
      source =
        module_with("""
        def check(a) do
          Decimal.positive?(a) or Decimal.nan?(a)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
