defmodule Mutare.Decimal.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/foxbenjaminfox/mutare_decimal"

  def project do
    [
      app: :mutare_decimal,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Mutation-testing mutators for Decimal — a Mutare plugin.",
      package: package(),
      lockfile: System.get_env("MIX_LOCKFILE", "mix.lock"),
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:mutare, path: "../mutare"},
      # Decimal backs only this package's own tests — the mutators match calls by
      # name, never call into Decimal. The requirement is env-overridable so CI can
      # sweep the declared range's major lines (see ci.yml); local runs fall back
      # to the locked (latest) Decimal.
      {:decimal, System.get_env("DECIMAL_REQUIREMENT", ">= 2.2.0 and < 4.0.0"), only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [check: ["format --check-formatted", "credo", "dialyzer"]]
  end

  defp dialyzer do
    [
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts",
      plt_add_apps: [:ex_unit, :mix],
      flags: [:error_handling, :extra_return, :missing_return]
    ]
  end

  # ExDoc configuration. `mix docs` renders to `doc/` (gitignored). README is the
  # landing page. Modules are grouped by what a mutation does — swap a call for a
  # sibling vs. remove/weaken it; `Mutare.Decimal.CallRebuild` is `@moduledoc false`
  # plumbing and never appears.
  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      groups_for_modules: [
        "Mutator front": [Mutare.Decimal],
        "Swap families": [
          Mutare.Decimal.Arithmetic,
          Mutare.Decimal.Comparison,
          Mutare.Decimal.Classification,
          Mutare.Decimal.ZeroBoundary,
          Mutare.Decimal.Sign,
          Mutare.Decimal.DivRem,
          Mutare.Decimal.ModeSwap
        ],
        "Drop / removal families": [
          Mutare.Decimal.Transform,
          Mutare.Decimal.DefaultDrop,
          Mutare.Decimal.LimitsDrop,
          Mutare.Decimal.Context
        ]
      ]
    ]
  end

  # Hex package metadata. The `mutare` core is still a `path:` dependency, so an
  # actual `mix hex.publish` stays blocked until Mutare itself ships to Hex — this
  # section keeps the manifest ready for that day. Only runtime and doc artifacts
  # ship — never the test suite.
  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Benjamin Fox"],
      links: %{
        "GitHub" => @source_url,
        "Mutare" => "https://hexdocs.pm/mutare",
        "Changelog" => "https://hexdocs.pm/mutare_decimal/changelog.html"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end
end
