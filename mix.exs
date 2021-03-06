defmodule TeleFlow.MixProject do
  use Mix.Project

  def project do
    [
      app: :teleflow,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:flow, "~> 1.2.0"},
      {:vega_lite, "~> 0.1.4"},
      # VegaLite dependency
      {:jason, "~> 1.2"},
      {:statistex, "~> 1.0"},
      {:telemetry, "~> 1.1.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
