defmodule Mutare.Decimal.ContextTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  alias Mutare.Decimal.Context, as: ContextMutator

  @mutators [ContextMutator]

  defp diffs(source), do: diffs_for(source, @mutators, :decimal_context)

  defp module_with(body) do
    """
    defmodule DecimalContextSample do
      #{body}
    end
    """
  end

  describe "Decimal.Context call mutations" do
    test "Decimal.Context.with/2 is replaced by a direct zero-arity function call" do
      assert diffs(module_with("def run(context, fun), do: Decimal.Context.with(context, fun)")) ==
               [{"Decimal.Context.with(context, fun)", "fun.()"}]
    end

    test "Decimal.Context.set/1 and update/1 are replaced by :ok" do
      assert diffs(module_with("def set(context), do: Decimal.Context.set(context)")) ==
               [{"Decimal.Context.set(context)", ":ok"}]

      assert diffs(module_with("def update(fun), do: Decimal.Context.update(fun)")) ==
               [{"Decimal.Context.update(fun)", ":ok"}]
    end

    test "piped context calls are skipped" do
      assert diffs(module_with("def set(context), do: context |> Decimal.Context.set()")) == []
      assert diffs(module_with("def update(fun), do: fun |> Decimal.Context.update()")) == []
    end
  end

  describe "written forms" do
    test "an aliased Decimal.Context call keeps the alias" do
      source = """
      defmodule DecimalContextAliasSample do
        alias Decimal.Context, as: C
        def set(context), do: C.set(context)
      end
      """

      assert diffs(source) == [{"C.set(context)", ":ok"}]
    end

    test "an imported Decimal.Context call is resolved" do
      source = """
      defmodule DecimalContextImportSample do
        import Decimal.Context
        def update(fun), do: update(fun)
      end
      """

      assert diffs(source) == [{"update(fun)", ":ok"}]
    end
  end

  describe "scope and metadata" do
    test "skips non-Decimal.Context calls and wrong arities" do
      assert diffs(module_with("def set(context), do: Other.Context.set(context)")) == []
      assert diffs(module_with("def set(a, b), do: Decimal.Context.set(a, b)")) == []
    end

    test "declares context operation variants" do
      assert ContextMutator.variants() == [:with, :set, :update]
    end

    test "tags call mutations" do
      source =
        module_with("""
        def set(context), do: Decimal.Context.set(context)
        def update(fun), do: Decimal.Context.update(fun)
        """)

      result = Mutare.transform_string(source, mutators: @mutators)

      assert Enum.map(result.mutants, & &1.variant) == [["set"], ["update"]]
    end

    test "qualified ignore suppresses only the requested context variant" do
      result =
        Mutare.transform_string(
          module_with(
            "def set(context), do: Decimal.Context.set(context) # mutare:ignore[decimal_context:set]"
          ),
          mutators: @mutators
        )

      assert [%{ignored: true, variant: ["set"]}] = result.mutants
    end

    test "every context mutant compiles" do
      source =
        module_with("""
        def run(context, fun) do
          Decimal.Context.with(context, fun)
          Decimal.Context.set(context)
          Decimal.Context.update(fun)
        end
        """)

      assert_metamutant_compiles(source, @mutators)
    end
  end
end
