defmodule Mutare.Decimal.TransformTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.Transform

  @mutators [Transform]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_transform)

  defp module_with(body) do
    """
    defmodule DecimalTransformSample do
      #{body}
    end
    """
  end

  describe "transform call removal" do
    test "one-argument transforms are replaced by their input" do
      assert diffs(module_with("def calc(a), do: Decimal.normalize(a)")) ==
               [{"Decimal.normalize(a)", "a"}]

      assert diffs(module_with("def calc(a), do: Decimal.negate(a)")) ==
               [{"Decimal.negate(a)", "a"}]
    end

    test "Decimal.round/1,2,3 are replaced by their input" do
      assert diffs(module_with("def calc(a), do: Decimal.round(a)")) ==
               [{"Decimal.round(a)", "a"}]

      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places)")) ==
               [{"Decimal.round(a, places)", "a"}]

      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :floor)")) ==
               [{"Decimal.round(a, places, :floor)", "a"}]
    end
  end

  describe "written forms" do
    test "an aliased Decimal call removes to the original input" do
      source = """
      defmodule DecimalTransformAliasSample do
        alias Decimal, as: D
        def calc(a), do: D.sqrt(a)
      end
      """

      assert diffs(source) == [{"D.sqrt(a)", "a"}]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalTransformImportSample do
        import Decimal
        def calc(a), do: normalize(a)
      end
      """

      assert diffs(source) == [{"normalize(a)", "a"}]
    end

    test "a piped call becomes Function.identity/1" do
      source = module_with("def calc(a), do: a |> Decimal.normalize()")

      assert diffs(source) == [{"Decimal.normalize()", "Elixir.Function.identity()"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls, wrong arities, and non-transform Decimal calls" do
      assert diffs(module_with("def calc(a), do: Other.normalize(a)")) == []
      assert diffs(module_with("def calc(a, b), do: Decimal.normalize(a, b)")) == []
      assert diffs(module_with("def calc(a), do: Decimal.to_string(a)")) == []
    end

    test "declares removed-function variants" do
      assert Transform.variants() == [:abs, :negate, :sqrt, :normalize, :apply_context, :round]
    end

    test "tags each mutation by the removed function" do
      source =
        module_with("""
        def normalize(a), do: Decimal.normalize(a)
        def round(a), do: Decimal.round(a)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [["normalize"], ["round"]]
    end

    test "qualified ignore suppresses only that removed function" do
      result =
        Mutare.transform_string(
          module_with(
            "def calc(a), do: Decimal.normalize(a) # mutare:ignore[decimal_transform:normalize]"
          ),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["normalize"]}] = result.mutants
    end

    test "every transform mutant compiles" do
      source =
        module_with("""
        def calc(a, places) do
          Decimal.normalize(a)
          Decimal.apply_context(a)
          Decimal.abs(a)
          Decimal.negate(a)
          Decimal.sqrt(a)
          Decimal.round(a, places, :floor)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
