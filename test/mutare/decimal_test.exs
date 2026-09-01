defmodule Mutare.DecimalTest do
  use ExUnit.Case, async: true

  import Mutare.Test

  test "all/0 returns every Decimal mutator family" do
    assert Mutare.Decimal.all() == [
             Mutare.Decimal.Arithmetic,
             Mutare.Decimal.Comparison,
             Mutare.Decimal.DefaultDrop,
             Mutare.Decimal.LimitsDrop,
             Mutare.Decimal.ModeSwap,
             Mutare.Decimal.Classification,
             Mutare.Decimal.ZeroBoundary,
             Mutare.Decimal.Transform,
             Mutare.Decimal.Sign,
             Mutare.Decimal.DivRem,
             Mutare.Decimal.Context
           ]
  end

  test "all/0 resolves through Mutare.Mutators.resolve/1 into one spec per family" do
    specs = Mutare.Mutators.resolve(Mutare.Decimal.all())

    assert Enum.map(specs, & &1.module) == Mutare.Decimal.all()

    assert Enum.map(specs, & &1.name) == [
             :decimal_arithmetic,
             :decimal_comparison,
             :decimal_default_drop,
             :decimal_limits_drop,
             :decimal_mode_swap,
             :decimal_classification,
             :decimal_zero_boundary,
             :decimal_transform,
             :decimal_sign,
             :decimal_div_rem,
             :decimal_context
           ]
  end

  describe "cross-family ownership" do
    test "DefaultDrop's mode drop and ModeSwap split round/3 without duplicate mutants" do
      source = """
      defmodule DecimalOwnershipRoundSample do
        def calc(a, places), do: Decimal.round(a, places, :half_even)
      end
      """

      assert diffs(source, [Mutare.Decimal.DefaultDrop, Mutare.Decimal.ModeSwap]) == [
               {:decimal_default_drop, "Decimal.round(a, places, :half_even)",
                "Decimal.round(a, places)"},
               {:decimal_mode_swap, "Decimal.round(a, places, :half_even)",
                "Decimal.round(a, places, :half_down)"}
             ]
    end

    test "LimitsDrop's format drop and ModeSwap split to_string/2 without duplicate mutants" do
      source = """
      defmodule DecimalOwnershipToStringSample do
        def render(a), do: Decimal.to_string(a, :normal)
      end
      """

      assert diffs(source, [Mutare.Decimal.LimitsDrop, Mutare.Decimal.ModeSwap]) == [
               {:decimal_limits_drop, "Decimal.to_string(a, :normal)", "Decimal.to_string(a)"},
               {:decimal_mode_swap, "Decimal.to_string(a, :normal)",
                "Decimal.to_string(a, :xsd)"},
               {:decimal_mode_swap, "Decimal.to_string(a, :normal)", "Decimal.to_string(a, :raw)"}
             ]
    end

    test "every emitted variant label is declared by its family" do
      source = """
      defmodule DecimalVariantVocabularySample do
        def calc(a, b, places, threshold, opts) do
          Decimal.add(a, b)
          Decimal.div(a, b)
          Decimal.div_int(a, b)
          Decimal.gt?(a, b)
          Decimal.gte?(a, b)
          Decimal.eq?(a, b)
          Decimal.min(a, b)
          Decimal.compare(a, b)
          Decimal.round(a, places)
          Decimal.round(a, places, :half_even)
          Decimal.round(a, places, :ceiling)
          Decimal.round(a, places, :up)
          Decimal.compare(a, b, threshold)
          Decimal.eq?(a, b, threshold)
          Decimal.parse("1", opts)
          Decimal.cast("1", opts)
          Decimal.new("1", opts)
          Decimal.to_string(a, :raw)
          Decimal.to_string(a, :scientific, opts)
          Decimal.positive?(a)
          Decimal.negative?(a)
          Decimal.nan?(a)
          Decimal.inf?(a)
          Decimal.normalize(a)
          Decimal.apply_context(a)
          Decimal.sqrt(a)
          Decimal.abs(a)
          Decimal.negate(a)
          Decimal.new(1, a, b)
          Decimal.new(-1, a, b)
          Decimal.div_rem(a, b)
          Decimal.Context.with(%Decimal.Context{}, fn -> a end)
          Decimal.Context.set(%Decimal.Context{})
          Decimal.Context.update(fn ctx -> ctx end)
        end
      end
      """

      result = Mutare.transform_string(source, mutators: Mutare.Decimal.all())

      declared =
        Map.new(Mutare.Decimal.all(), fn family ->
          {family.name(), MapSet.new(family.variants(), &to_string/1)}
        end)

      emitted =
        result.mutants
        |> Enum.group_by(& &1.mutator, &List.wrap(&1.variant))
        |> Map.new(fn {family, variants} ->
          {family, variants |> List.flatten() |> MapSet.new()}
        end)

      assert Map.keys(emitted) |> Enum.sort() == Map.keys(declared) |> Enum.sort()

      for {family, labels} <- emitted do
        assert MapSet.subset?(labels, declared[family]),
               "#{family} emitted undeclared variants: " <>
                 inspect(MapSet.difference(labels, declared[family]) |> MapSet.to_list())
      end
    end
  end
end
