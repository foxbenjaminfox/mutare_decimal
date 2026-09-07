defmodule Mutare.Decimal.LimitsDropTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.LimitsDrop

  @mutators [LimitsDrop]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_limits_drop)

  defp module_with(body) do
    """
    defmodule DecimalLimitsDropSample do
      #{body}
    end
    """
  end

  describe "limit/default argument drops" do
    test "Decimal.parse/2, cast/2, and new/2 drop parsing options" do
      assert diffs(
               module_with("def parse(input), do: Decimal.parse(input, max_digits: :infinity)")
             ) ==
               [{"Decimal.parse(input, max_digits: :infinity)", "Decimal.parse(input)"}]

      assert diffs(module_with("def cast(input, opts), do: Decimal.cast(input, opts)")) ==
               [{"Decimal.cast(input, opts)", "Decimal.cast(input)"}]

      assert diffs(module_with("def new(input, opts), do: Decimal.new(input, opts)")) ==
               [{"Decimal.new(input, opts)", "Decimal.new(input)"}]
    end

    test "Decimal.to_string/3 drops rendering options and to_string/2 drops the format" do
      assert diffs(
               module_with(
                 "def render(num), do: Decimal.to_string(num, :normal, max_digits: :infinity)"
               )
             ) == [
               {"Decimal.to_string(num, :normal, max_digits: :infinity)",
                "Decimal.to_string(num, :normal)"}
             ]

      assert diffs(module_with("def render(num), do: Decimal.to_string(num, :normal)")) ==
               [{"Decimal.to_string(num, :normal)", "Decimal.to_string(num)"}]
    end

    test "skips literal values equivalent to Decimal defaults" do
      assert diffs(module_with("def parse(input), do: Decimal.parse(input, [])")) == []

      assert diffs(
               module_with(
                 "def parse(input), do: Decimal.parse(input, max_digits: 34, max_exponent: 6144)"
               )
             ) == []

      assert diffs(module_with("def render(num), do: Decimal.to_string(num, :scientific)")) == []
      assert diffs(module_with("def render(num), do: Decimal.to_string(num, :normal, [])")) == []

      assert diffs(module_with("def render(num), do: Decimal.to_string(num, :normal, foo: :bar)")) ==
               []
    end
  end

  describe "written forms" do
    test "an aliased Decimal call keeps the alias" do
      source = """
      defmodule DecimalLimitsDropAliasSample do
        alias Decimal, as: D
        def parse(input, opts), do: D.parse(input, opts)
      end
      """

      assert diffs(source) == [{"D.parse(input, opts)", "D.parse(input)"}]
    end

    test "an imported Decimal call is resolved" do
      source = """
      defmodule DecimalLimitsDropImportSample do
        import Decimal
        def parse(input, opts), do: parse(input, opts)
      end
      """

      # Bare-import resolution reflects on the module's real exports, and `Decimal.parse/2`
      # arrived in Decimal 2.4 — against an older Decimal (the CI minimum is 2.2) the bare
      # call is not a Decimal call at all, so it rightly draws no mutant.
      expected =
        if function_exported?(Decimal, :parse, 2),
          do: [{"parse(input, opts)", "parse(input)"}],
          else: []

      assert diffs(source) == expected
    end

    test "an imported Decimal drop is qualified when the dropped arity hits Kernel" do
      source = """
      defmodule DecimalLimitsDropImportKernelOverlapSample do
        import Decimal
        def render(num), do: to_string(num, :normal)
      end
      """

      assert diffs(source) == [{"to_string(num, :normal)", "Elixir.Decimal.to_string(num)"}]
    end

    test "a piped call drops the visible trailing argument" do
      source = module_with("def parse(input, opts), do: input |> Decimal.parse(opts)")

      assert diffs(source) == [{"Decimal.parse(opts)", "Decimal.parse()"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal calls and wrong arities" do
      assert diffs(module_with("def parse(input, opts), do: Other.parse(input, opts)")) == []
      assert diffs(module_with("def parse(input), do: Decimal.parse(input)")) == []

      assert diffs(
               module_with("def render(num), do: Decimal.to_string(num, :normal, [], :extra)")
             ) == []
    end

    test "declares dropped-argument variants" do
      assert LimitsDrop.variants() == [
               :parse_options,
               :cast_options,
               :new_options,
               :to_string_options,
               :string_format
             ]
    end

    test "tags each mutation by the argument it drops" do
      source =
        module_with("""
        def parse(input, opts), do: Decimal.parse(input, opts)
        def render(num), do: Decimal.to_string(num, :normal)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [["parse_options"], ["string_format"]]
    end

    test "qualified ignore suppresses only the requested drop" do
      result =
        Mutare.transform_string(
          module_with(
            "def parse(input, opts), do: Decimal.parse(input, opts) # mutare:ignore[decimal_limits_drop:parse_options]"
          ),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["parse_options"]}] = result.mutants
    end

    test "every limits-drop mutant compiles" do
      source =
        module_with("""
        def run(input, opts, num) do
          Decimal.parse(input, opts)
          Decimal.cast(input, opts)
          Decimal.new(input, opts)
          Decimal.to_string(num, :normal, max_digits: :infinity)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end

    test "imported limits-drop mutants that overlap Kernel compile" do
      source = """
      defmodule DecimalLimitsDropImportedCompileSample do
        import Decimal
        def render(num), do: to_string(num, :normal)
      end
      """

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
