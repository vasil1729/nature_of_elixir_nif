defmodule Lab.Native.MixProject do
  use Mix.Project

  def project do
    [
      app: :lab_native,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: Mix.compilers()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:rustler, "~> 0.38.0"}
    ]
  end
end
