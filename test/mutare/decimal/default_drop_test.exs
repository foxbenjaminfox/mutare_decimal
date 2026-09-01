defmodule Mutare.Decimal.DefaultDropTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.DefaultDrop

  @mutators [DefaultDrop]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_default_drop)

  defp module_with(body) do
    """
    defmodule DecimalDefaultDropSample do
      #{body}
    end
    """
  end

  describe "default/refinement argument drops" do
    test "Decimal.round/2 drops places" do
      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places)")) ==
               [{"Decimal.round(a, places)", "Decimal.round(a)"}]
    end

    test "Decimal.round/3 drops rounding mode" do
      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :floor)")) ==
               [{"Decimal.round(a, places, :floor)", "Decimal.round(a, places)"}]
    end

    test "Decimal.compare/3 and eq?/3 drop threshold" do
      assert diffs(module_with("def cmp(a, b, threshold), do: Decimal.compare(a, b, threshold)")) ==
               [{"Decimal.compare(a, b, threshold)", "Decimal.compare(a, b)"}]

      assert diffs(module_with("def eq(a, b, threshold), do: Decimal.eq?(a, b, threshold)")) ==
               [{"Decimal.eq?(a, b, threshold)", "Decimal.eq?(a, b)"}]
    end

    test "skips literal values equivalent to defaults" do
      assert diffs(module_with("def calc(a), do: Decimal.round(a, 0)")) == []

      assert diffs(module_with("def calc(a, places), do: Decimal.round(a, places, :half_up)")) ==
               []

      assert diffs(module_with(~s|def cmp(a, b), do: Decimal.compare(a, b, "0.0")|)) == []
      assert diffs(module_with(~s|def eq(a, b), do: Decimal.eq?(a, b, "0e2")|)) == []
    end

    test "leaves literal-number refinements to the numeric literal families" do
      assert diffs(module_with("def calc(a), do: Decimal.round(a, 2)")) == []
      assert diffs(module_with("def calc(a), do: Decimal.round(a, -2)")) == []
      assert diffs(module_with("def cmp(a, b), do: Decimal.compare(a, b, 1)")) == []
      assert diffs(module_with("def eq(a, b), do: Decimal.eq?(a, b, 1)")) == []
    end

    test "drops a non-zero string threshold, which no numeric family perturbs to zero" do
      assert diffs(module_with(~s|def cmp(a, b), do: Decimal.compare(a, b, "0.5")|)) ==
               [{~s|Decimal.compare(a, b, "0.5")|, "Decimal.compare(a, b)"}]
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalDefaultDropAliasSample do
        alias Decimal, as: D
        def calc(a, places), do: D.round(a, places)
      end
      """

      assert diffs(source) == [{"D.round(a, places)", "D.round(a)"}]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalDefaultDropImportSample do
        import Decimal
        def calc(a, places), do: round(a, places)
      end
      """

      assert diffs(source) == [{"round(a, places)", "Elixir.Decimal.round(a)"}]
    end

    test "an imported Decimal pipe stage is qualified when the dropped arity hits Kernel" do
      source = """
      defmodule DecimalDefaultDropImportPipeSample do
        import Decimal
        def calc(a, places), do: a |> round(places)
      end
      """

      assert diffs(source) == [{"round(places)", "Elixir.Decimal.round()"}]
    end

    test "an imported Decimal call stays bare when the dropped arity does not hit Kernel" do
      source = """
      defmodule DecimalDefaultDropImportSafeSample do
        import Decimal
        def calc(a, places, mode), do: round(a, places, mode)
      end
      """

      assert diffs(source) == [{"round(a, places, mode)", "round(a, places)"}]
    end

    test "a piped call drops the visible trailing argument" do
      source = module_with("def calc(a, places), do: a |> Decimal.round(places)")

      assert diffs(source) == [{"Decimal.round(places)", "Decimal.round()"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls and wrong arities" do
      assert diffs(module_with("def calc(a, places), do: Other.round(a, places)")) == []
      assert diffs(module_with("def calc(a), do: Decimal.round(a)")) == []
      assert diffs(module_with("def cmp(a, b), do: Decimal.compare(a, b)")) == []
    end

    test "declares dropped-argument variants" do
      assert DefaultDrop.variants() == [:places, :rounding, :threshold]
    end

    test "tags each mutation by the argument it drops" do
      source =
        module_with("""
        def round(a, places, mode), do: Decimal.round(a, places, mode)
        def cmp(a, b, threshold), do: Decimal.compare(a, b, threshold)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [["rounding"], ["threshold"]]
    end

    test "qualified ignore suppresses only the requested drop" do
      result =
        Mutare.transform_string(
          module_with(
            "def calc(a, places, mode), do: Decimal.round(a, places, mode) # mutare:ignore[decimal_default_drop:rounding]"
          ),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["rounding"]}] = result.mutants
    end

    test "every default-drop mutant compiles" do
      source =
        module_with("""
        def calc(a, b, places, mode, threshold) do
          Decimal.round(a, places, mode)
          Decimal.compare(a, b, threshold)
          Decimal.eq?(a, b, threshold)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end

    test "imported default-drop mutants that overlap Kernel compile" do
      source = """
      defmodule DecimalDefaultDropImportedCompileSample do
        import Decimal
        def calc(a, places), do: round(a, places)
      end
      """

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
