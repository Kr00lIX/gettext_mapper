defmodule GettextMapper.MixProject do
  use Mix.Project

  @version "0.1.2"
  @github_url "https://github.com/kr00lix/gettext_mapper"

  def project do
    [
      app: :gettext_mapper,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "Ecto.Type for translated JSON maps",
      package: package(),

      # Docs
      name: "GettextMapper",
      source_url: @github_url,
      docs: docs(),

      # Test coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.post": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.0"},
      {:gettext, ">= 0.26.0 and < 2.0.0"},

      # Documentation
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},

      # Code analysis
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false},

      # Test
      {:excoveralls, "~> 0.18", only: :test},
      {:junit_formatter, "~> 3.4", only: :test}
    ]
  end

  defp docs do
    [
      main: "GettextMapper",
      source_ref: "v#{@version}",
      extras: ["README.md"],
      source_url: @github_url
    ]
  end

  defp package do
    %{
      name: "gettext_mapper",
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url},
      files: ~w(.formatter.exs mix.exs README.md lib)
    }
  end
end
