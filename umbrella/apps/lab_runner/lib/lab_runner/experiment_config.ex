defmodule Lab.ExperimentConfig do
  @moduledoc """
  Loads experiment configuration from `experiments/E##_*/config.exs`.

  Each config file returns a map with:

    * `:id`           — atom (e.g. `:E02`)
    * `:slug`         — string directory slug (e.g. `"cpu_dirty_nif"`)
    * `:mode`         — `:in_process` or `:isolated`
    * `:tags`         — list of atoms (e.g. `[:slow, :crash]`)
    * `:nif`          — `{module, function, arity}` for NIF-based experiments
    * `:port_cmd`     — string for port-based experiments
    * `:params`       — map of param specs with defaults, min, max, label
    * `:thresholds`   — map of assertion thresholds
    * `:time_budget_ms` — Watchdog timeout (default: 120_000)
    * `:hypothesis`   — string for the report

  See docs/10_development_guide.md and docs/06_reproducibility_protocol.md.
  """

  defp experiments_root do
    Application.get_env(:lab_runner, :experiments_root) ||
      raise("Set config :lab_runner, :experiments_root in config.exs")
  end

  @doc "Loads the config for experiment `id` (e.g. `:E02` or `\"E02\"`)."
  def load!(id) when is_atom(id) or is_binary(id) do
    id_str = id |> to_string() |> String.upcase()
    dir = find_experiment_dir(id_str)

    if dir == nil do
      raise "Experiment #{id_str} not found in #{experiments_root()}/"
    end

    config_path = Path.join(dir, "config.exs")

    if File.exists?(config_path) do
      config = File.read!(config_path) |> Code.eval_string() |> elem(0)
      Map.put(config, :__dir__, dir)
    else
      raise "Config file not found: #{config_path}"
    end
  end

  @doc "Lists all experiment IDs found in the experiments/ directory."
  def list_ids do
    Path.wildcard(Path.join([experiments_root(), "E*"]))
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(fn path ->
      Path.basename(path) |> String.split("_") |> List.first()
    end)
    |> Enum.sort()
  end

  defp find_experiment_dir(id_str) do
    Path.wildcard(Path.join([experiments_root(), "#{id_str}_*"]))
    |> List.first()
  end
end
