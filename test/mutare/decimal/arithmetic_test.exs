defmodule Mutare.Decimal.ArithmeticTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.Arithmetic

  @mutators [Arithmetic]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_arithmetic)

  defp module_with(body) do
    """
    defmodule DecimalArithmeticSample do
      #{body}
    end
    """
  end

  describe "arithmetic call swaps" do
    test "Decimal.add/2 mutates to sub/2 and mult/2" do
      source = module_with("def calc(a, b), do: Decimal.add(a, b)")

      assert diffs(source) == [
               {"Decimal.add(a, b)", "Decimal.sub(a, b)"},
               {"Decimal.add(a, b)", "Decimal.mult(a, b)"}
             ]
    end

    test "Decimal.mult/2 and Decimal.div/2 swap with related operations" do
      assert diffs(module_with("def calc(a, b), do: Decimal.mult(a, b)")) ==
               [{"Decimal.mult(a, b)", "Decimal.div(a, b)"}]

      assert diffs(module_with("def calc(a, b), do: Decimal.div(a, b)")) ==
               [
                 {"Decimal.div(a, b)", "Decimal.mult(a, b)"},
                 {"Decimal.div(a, b)", "Decimal.div_int(a, b)"},
                 {"Decimal.div(a, b)", "Decimal.div(b, a)"}
               ]
    end

    test "Decimal.div_int/2 and Decimal.rem/2 swap with related operations" do
      assert diffs(module_with("def calc(a, b), do: Decimal.div_int(a, b)")) ==
               [
                 {"Decimal.div_int(a, b)", "Decimal.rem(a, b)"},
                 {"Decimal.div_int(a, b)", "Decimal.div(a, b)"},
                 {"Decimal.div_int(a, b)", "Decimal.div_int(b, a)"}
               ]

      assert diffs(module_with("def calc(a, b), do: Decimal.rem(a, b)")) ==
               [
                 {"Decimal.rem(a, b)", "Decimal.div_int(a, b)"},
                 {"Decimal.rem(a, b)", "Decimal.rem(b, a)"}
               ]
    end

    test "Decimal.sub/2 reverses visible operands" do
      assert diffs(module_with("def calc(a, b), do: Decimal.sub(a, b)")) ==
               [
                 {"Decimal.sub(a, b)", "Decimal.add(a, b)"},
                 {"Decimal.sub(a, b)", "Decimal.sub(b, a)"}
               ]
    end

    test "operand reversal skips identical operands and piped calls" do
      assert diffs(module_with("def calc(a), do: Decimal.sub(a, a)")) ==
               [{"Decimal.sub(a, a)", "Decimal.add(a, a)"}]

      assert diffs(module_with("def calc(a, b), do: a |> Decimal.sub(b)")) ==
               [{"Decimal.sub(b)", "Decimal.add(b)"}]
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalArithmeticAliasSample do
        alias Decimal, as: D
        def calc(a, b), do: D.sub(a, b)
      end
      """

      assert diffs(source) == [
               {"D.sub(a, b)", "D.add(a, b)"},
               {"D.sub(a, b)", "D.sub(b, a)"}
             ]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalArithmeticImportSample do
        import Decimal
        def calc(a, b), do: add(a, b)
      end
      """

      assert diffs(source) == [
               {"add(a, b)", "sub(a, b)"},
               {"add(a, b)", "mult(a, b)"}
             ]
    end

    test "imported Decimal replacements are qualified when they overlap Kernel" do
      source = """
      defmodule DecimalArithmeticImportKernelOverlapSample do
        import Decimal
        def calc(a, b), do: div_int(a, b)
      end
      """

      assert diffs(source) == [
               {"div_int(a, b)", "Elixir.Decimal.rem(a, b)"},
               {"div_int(a, b)", "Elixir.Decimal.div(a, b)"},
               {"div_int(a, b)", "div_int(b, a)"}
             ]
    end

    test "a piped call uses effective arity and mutates the stage" do
      source = module_with("def calc(a, b), do: a |> Decimal.mult(b)")

      assert diffs(source) == [{"Decimal.mult(b)", "Decimal.div(b)"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls and wrong arities" do
      assert diffs(module_with("def calc(a, b), do: Other.mult(a, b)")) == []
      assert diffs(module_with("def calc(a), do: Decimal.mult(a)")) == []
      assert diffs(module_with("def calc(a, b, c), do: Decimal.add(a, b, c)")) == []
    end

    test "declares target-operation variants" do
      assert Arithmetic.variants() == [:sub, :mult, :add, :div, :rem, :div_int, :operands]
    end

    test "tags each mutation by the operation it becomes" do
      result =
        Mutare.transform_string(module_with("def calc(a, b), do: Decimal.add(a, b)"),
          mutators: @mutators
        )

      variants = Enum.map(result.mutants, & &1.variant)

      assert variants == [["sub"], ["mult"]]
    end

    test "qualified ignore suppresses only that target operation" do
      result =
        Mutare.transform_string(
          module_with(
            "def calc(a, b), do: Decimal.add(a, b) # mutare:ignore[decimal_arithmetic:mult]"
          ),
          mutators: @mutators
        )

      ignored_by_variant = Map.new(result.mutants, &{&1.variant, &1.ignored})

      assert ignored_by_variant[["sub"]] == false
      assert ignored_by_variant[["mult"]] == true
    end

    test "every arithmetic mutant compiles" do
      source =
        module_with("""
        def calc(a, b) do
          a
          |> Decimal.mult(b)
          |> Decimal.add(Decimal.rem(a, b))
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end

    test "imported arithmetic mutants that overlap Kernel compile" do
      source = """
      defmodule DecimalArithmeticImportedCompileSample do
        import Decimal
        def calc(a, b), do: div_int(a, b)
      end
      """

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
