defmodule Mutare.Decimal.ComparisonTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.Comparison

  @mutators [Comparison]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_comparison)

  defp module_with(body) do
    """
    defmodule DecimalComparisonSample do
      #{body}
    end
    """
  end

  describe "predicate swaps" do
    test "Decimal.gt?/2 mutates to boundary, direction, and complement siblings" do
      source = module_with("def greater?(a, b), do: Decimal.gt?(a, b)")

      assert diffs(source) == [
               {"Decimal.gt?(a, b)", "Decimal.gte?(a, b)"},
               {"Decimal.gt?(a, b)", "Decimal.lt?(a, b)"},
               {"Decimal.gt?(a, b)", "Decimal.lte?(a, b)"}
             ]
    end

    test "Decimal.gte?/2, lt?/2, and lte?/2 mutate" do
      assert diffs(module_with("def check(a, b), do: Decimal.gte?(a, b)")) == [
               {"Decimal.gte?(a, b)", "Decimal.gt?(a, b)"},
               {"Decimal.gte?(a, b)", "Decimal.lte?(a, b)"},
               {"Decimal.gte?(a, b)", "Decimal.lt?(a, b)"}
             ]

      assert diffs(module_with("def check(a, b), do: Decimal.lt?(a, b)")) == [
               {"Decimal.lt?(a, b)", "Decimal.lte?(a, b)"},
               {"Decimal.lt?(a, b)", "Decimal.gt?(a, b)"},
               {"Decimal.lt?(a, b)", "Decimal.gte?(a, b)"}
             ]

      assert diffs(module_with("def check(a, b), do: Decimal.lte?(a, b)")) == [
               {"Decimal.lte?(a, b)", "Decimal.lt?(a, b)"},
               {"Decimal.lte?(a, b)", "Decimal.gte?(a, b)"},
               {"Decimal.lte?(a, b)", "Decimal.gt?(a, b)"}
             ]
    end

    test "Decimal.eq?/2 and equal?/2 mutate to strict ordering checks" do
      assert diffs(module_with("def check(a, b), do: Decimal.eq?(a, b)")) == [
               {"Decimal.eq?(a, b)", "Decimal.gt?(a, b)"},
               {"Decimal.eq?(a, b)", "Decimal.lt?(a, b)"}
             ]

      assert diffs(module_with("def check(a, b), do: Decimal.equal?(a, b)")) == [
               {"Decimal.equal?(a, b)", "Decimal.gt?(a, b)"},
               {"Decimal.equal?(a, b)", "Decimal.lt?(a, b)"}
             ]
    end

    test "Decimal.min/2 and max/2 swap" do
      assert diffs(module_with("def pick(a, b), do: Decimal.max(a, b)")) ==
               [{"Decimal.max(a, b)", "Decimal.min(a, b)"}]

      assert diffs(module_with("def pick(a, b), do: Decimal.min(a, b)")) ==
               [{"Decimal.min(a, b)", "Decimal.max(a, b)"}]
    end
  end

  describe "compare/cmp operand reversal" do
    test "Decimal.compare/2 reverses the first two operands" do
      assert diffs(module_with("def cmp(a, b), do: Decimal.compare(a, b)")) ==
               [{"Decimal.compare(a, b)", "Decimal.compare(b, a)"}]
    end

    test "Decimal.compare/3 keeps the threshold as the third argument" do
      assert diffs(module_with("def cmp(a, b, t), do: Decimal.compare(a, b, t)")) ==
               [{"Decimal.compare(a, b, t)", "Decimal.compare(b, a, t)"}]
    end

    test "deprecated Decimal.cmp/2 is covered for older codebases" do
      assert diffs(module_with("def cmp(a, b), do: Decimal.cmp(a, b)")) ==
               [{"Decimal.cmp(a, b)", "Decimal.cmp(b, a)"}]
    end

    test "piped compare is skipped because the first operand is not visible" do
      assert diffs(module_with("def cmp(a, b), do: a |> Decimal.compare(b)")) == []
    end

    test "reversal skips identical operands, which would re-render the original" do
      assert diffs(module_with("def cmp(a), do: Decimal.compare(a, a)")) == []
      assert diffs(module_with("def cmp(a, t), do: Decimal.compare(a, a, t)")) == []
      assert diffs(module_with("def cmp(a), do: Decimal.cmp(a, a)")) == []
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalComparisonAliasSample do
        alias Decimal, as: D
        def check(a, b), do: D.gt?(a, b)
      end
      """

      assert diffs(source) == [
               {"D.gt?(a, b)", "D.gte?(a, b)"},
               {"D.gt?(a, b)", "D.lt?(a, b)"},
               {"D.gt?(a, b)", "D.lte?(a, b)"}
             ]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalComparisonImportSample do
        import Decimal
        def check(a, b), do: gt?(a, b)
      end
      """

      assert diffs(source) == [
               {"gt?(a, b)", "gte?(a, b)"},
               {"gt?(a, b)", "lt?(a, b)"},
               {"gt?(a, b)", "lte?(a, b)"}
             ]
    end

    test "a piped predicate call uses effective arity and mutates the stage" do
      source = module_with("def check(a, b), do: a |> Decimal.gt?(b)")

      assert diffs(source) == [
               {"Decimal.gt?(b)", "Decimal.gte?(b)"},
               {"Decimal.gt?(b)", "Decimal.lt?(b)"},
               {"Decimal.gt?(b)", "Decimal.lte?(b)"}
             ]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls, wrong arities, and threshold eq?/3" do
      assert diffs(module_with("def check(a, b), do: Other.gt?(a, b)")) == []
      assert diffs(module_with("def check(a), do: Decimal.gt?(a)")) == []
      assert diffs(module_with("def check(a, b, t), do: Decimal.eq?(a, b, t)")) == []
    end

    test "declares function-target and operand variants" do
      assert Comparison.variants() == [:gte?, :lt?, :gt?, :lte?, :min, :max, :operands]
    end

    test "tags function swaps and operand reversal" do
      source =
        module_with("""
        def check(a, b), do: Decimal.gt?(a, b)
        def cmp(a, b), do: Decimal.compare(a, b)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [
               ["gte?"],
               ["lt?"],
               ["lte?"],
               ["operands"]
             ]
    end

    test "qualified ignore suppresses only the requested comparison variant" do
      result =
        Mutare.transform_string(
          module_with(
            "def check(a, b), do: Decimal.gt?(a, b) # mutare:ignore[decimal_comparison:lt?]"
          ),
          mutators: @mutators
        )

      ignored_by_variant = Map.new(result.mutants, &{&1.variant, &1.ignored})

      assert ignored_by_variant[["gte?"]] == false
      assert ignored_by_variant[["lt?"]] == true
      assert ignored_by_variant[["lte?"]] == false
    end

    test "every comparison mutant compiles" do
      source =
        module_with("""
        def check(a, b, threshold) do
          Decimal.gt?(a, b) or
            Decimal.eq?(a, b) or
            Decimal.max(a, b) == a or
            Decimal.compare(a, b, threshold) == :gt
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
