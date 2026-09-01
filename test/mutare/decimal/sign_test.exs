defmodule Mutare.Decimal.SignTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.Sign

  @mutators [Sign]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_sign)

  defp module_with(body) do
    """
    defmodule DecimalSignSample do
      #{body}
    end
    """
  end

  describe "sign call swaps" do
    test "Decimal.abs/1 and negate/1 swap" do
      assert diffs(module_with("def calc(a), do: Decimal.abs(a)")) ==
               [{"Decimal.abs(a)", "Decimal.negate(a)"}]

      assert diffs(module_with("def calc(a), do: Decimal.negate(a)")) ==
               [{"Decimal.negate(a)", "Decimal.abs(a)"}]
    end

    test "Decimal.new/3 flips literal constructor signs" do
      assert diffs(module_with("def new(coef, exp), do: Decimal.new(1, coef, exp)")) ==
               [{"Decimal.new(1, coef, exp)", "Decimal.new(-1, coef, exp)"}]

      assert diffs(module_with("def new(coef, exp), do: Decimal.new(-1, coef, exp)")) ==
               [{"Decimal.new(-1, coef, exp)", "Decimal.new(1, coef, exp)"}]
    end

    test "skips non-literal constructor signs and piped constructor signs" do
      assert diffs(module_with("def new(sign, coef, exp), do: Decimal.new(sign, coef, exp)")) ==
               []

      assert diffs(module_with("def new(sign, coef, exp), do: sign |> Decimal.new(coef, exp)")) ==
               []
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalSignAliasSample do
        alias Decimal, as: D
        def calc(a), do: D.abs(a)
      end
      """

      assert diffs(source) == [{"D.abs(a)", "D.negate(a)"}]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalSignImportSample do
        import Decimal
        def calc(a), do: negate(a)
      end
      """

      assert diffs(source) == [{"negate(a)", "Elixir.Decimal.abs(a)"}]
    end

    test "a piped call uses effective arity and mutates the stage" do
      source = module_with("def calc(a), do: a |> Decimal.abs()")

      assert diffs(source) == [{"Decimal.abs()", "Decimal.negate()"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls and wrong arities" do
      assert diffs(module_with("def calc(a), do: Other.abs(a)")) == []
      assert diffs(module_with("def calc(a, b), do: Decimal.abs(a, b)")) == []
      assert diffs(module_with("def new(a), do: Decimal.new(a)")) == []
    end

    test "declares sign variants" do
      assert Sign.variants() == [:negate, :abs, :negative, :positive]
    end

    test "tags function and constructor sign swaps" do
      source =
        module_with("""
        def calc(a), do: Decimal.abs(a)
        def new(coef, exp), do: Decimal.new(1, coef, exp)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [["negate"], ["negative"]]
    end

    test "qualified ignore suppresses only the requested sign variant" do
      result =
        Mutare.transform_string(
          module_with("def calc(a), do: Decimal.abs(a) # mutare:ignore[decimal_sign:negate]"),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["negate"]}] = result.mutants
    end

    test "every sign mutant compiles" do
      source =
        module_with("""
        def calc(a, coef, exp) do
          Decimal.abs(a)
          Decimal.negate(a)
          Decimal.new(1, coef, exp)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end

    test "imported sign mutants that overlap Kernel compile" do
      source = """
      defmodule DecimalSignImportedCompileSample do
        import Decimal
        def calc(a), do: negate(a)
      end
      """

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
