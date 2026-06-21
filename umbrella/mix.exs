defmodule Lab.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixir: "~> 1.18",
      preferred_cli_env: [
        test: :test,
        "test.slow": :test,
        "test.crash": :test,
        "test.oban": :test
      ]
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["test"],
      # Characterization suite (excluded by default; opt-in)
      "test.slow": ["test --only slow"],
      "test.crash": ["test --only crash"],
      "test.oban": ["test --only oban"]
    ]
  end
end
