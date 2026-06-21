defmodule Lab.ExperimentCase do
  @moduledoc """
  ExUnit case template for characterization experiments.

  Each experiment's test file uses this module:

      defmodule E01Test do
        use Lab.ExperimentCase, experiment: :E01
        @moduletag :slow

        setup do
          {:ok, config: Lab.ExperimentConfig.load!(:E01)}
        end

        test "E01: normal NIF blocks schedulers", %{config: config} do
          {:ok, result} = Lab.Runner.run_with_config(config)
          assert_all_passed(result)
        end
      end

  This module provides:
    * assert_all_passed/1 — checks all threshold assertions
    * assert_crashed/1 — checks exit code != 0 (for @crash experiments)
    * assert_threshold/2 — checks a specific threshold by name
    * assert_threshold_failed/2 — checks a threshold FAILED (for findings)

  See docs/06_reproducibility_protocol.md and docs/10_development_guide.md.
  """

  use ExUnit.CaseTemplate

  using opts do
    experiment_id = Keyword.fetch!(opts, :experiment)

    quote do
      use ExUnit.Case, async: false

      import Lab.ExperimentCase

      setup_all do
        config = Lab.ExperimentConfig.load!(unquote(experiment_id))
        {:ok, config: config}
      end
    end
  end

  @doc """
  Runs the experiment with default or overridden params.

  Requires `config` in the ExUnit context (set by setup_all).
  """
  def run_experiment(ctx, opts \\ []) do
    config = Map.fetch!(ctx, :config)
    params = Keyword.get(opts, :params, %{})
    Lab.Runner.run_with_config(config, params: params)
  end

  @doc """
  Asserts all threshold assertions passed. Produces a helpful error
  message listing which assertions failed.
  """
  defmacro assert_all_passed(result) do
    quote do
      result = unquote(result)

      assert result.assertion_fail == 0,
        """
        #{result.experiment_id}: #{result.assertion_fail} assertion(s) failed.

        Exit code: #{result.exit_code}

        Assertion results:
        #{Lab.ExperimentCase.format_assertions(result.assertions)}

        Report: #{result.report_path}
        """
    end
  end

  @doc "Asserts that the BEAM crashed (exit code != 0). For @crash experiments."
  defmacro assert_crashed(result) do
    quote do
      result = unquote(result)
      assert result.exit_code != 0,
        "#{result.experiment_id}: expected BEAM to crash but exit code was #{result.exit_code}"
    end
  end

  @doc "Asserts a specific threshold by name passed."
  defmacro assert_threshold(result, key) do
    quote do
      result = unquote(result)
      key = unquote(key)
      passed? = Map.get(result.assertions, key)

      assert passed?,
        "#{result.experiment_id}: threshold #{key} failed (expected to pass)"
    end
  end

  @doc "Asserts a specific threshold FAILED. For experiments that expect degradation."
  defmacro assert_threshold_failed(result, key) do
    quote do
      result = unquote(result)
      key = unquote(key)
      passed? = Map.get(result.assertions, key)

      refute passed?,
        "#{result.experiment_id}: threshold #{key} passed (expected to fail — this is a finding)"
    end
  end

  @doc false
  def format_assertions(assertions) do
    assertions
    |> Enum.map(fn {key, passed?} ->
      status = if passed?, do: "PASS", else: "FAIL"
      "  [#{status}] #{key}"
    end)
    |> Enum.join("\n")
  end
end
