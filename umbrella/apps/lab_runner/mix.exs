defmodule Lab.Runner.MixProject do
  use Mix.Project

  def project do
    [
      app: :lab_runner,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Lab.Runner.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      {:oban, "~> 2.18"},
      {:jason, "~> 1.4"},
      {:lab_core, in_umbrella: true},
      {:lab_native, in_umbrella: true},
      {:lab_port, in_umbrella: true}
    ]
  end
end
