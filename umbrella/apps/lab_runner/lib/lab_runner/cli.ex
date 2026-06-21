defmodule Lab.Runner.CLI do
  @moduledoc """
  CLI entry point for headless experiment execution.

  Usage:
      elixir -e Lab.Runner.CLI.main(["E02"])
      elixir -e Lab.Runner.CLI.main(["E02", "--params", "duration_ms=60000"])

  Exits with 0 on all-assertions-pass, 1 on any failure, 2 on crash.
  """

  require Logger

  def main(args) do
    {opts, rest, _invalid} = parse_args(args)

    if rest == [] do
      IO.puts("Usage: Lab.Runner.CLI.main([\"E##\", \"--params\", \"key=value\", ...])")
      IO.puts("Available experiments: #{inspect(Lab.ExperimentConfig.list_ids())}")
      System.halt(1)
    end

    exp_id = String.to_atom(hd(rest))
    params = parse_params(Keyword.get_values(opts, :params))

    Logger.info("Running #{exp_id} with params=#{inspect(params)}")

    case Lab.Runner.run(exp_id, params: params) do
      {:ok, result} ->
        IO.puts("\n=== #{exp_id} Results ===")
        IO.puts("Exit code: #{result.exit_code}")
        IO.puts("Assertions: #{result.assertion_pass} pass, #{result.assertion_fail} fail")

        for {key, passed?} <- result.assertions do
          status = if passed?, do: "PASS", else: "FAIL"
          IO.puts("  [#{status}] #{key}")
        end

        IO.puts("\nReport: #{result.report_path}")
        IO.puts("Data:   #{result.data_path}")

        cond do
          result.exit_code != 0 -> System.halt(2)
          result.assertion_fail > 0 -> System.halt(1)
          true -> System.halt(0)
        end

      error ->
        IO.puts(:stderr, "Error: #{inspect(error)}")
        System.halt(2)
    end
  end

  defp parse_args(args) do
    OptionParser.parse(args,
      strict: [params: :keep],
      aliases: [p: :params]
    )
  end

  defp parse_params(param_strings) do
    Enum.reduce(param_strings, %{}, fn str, acc ->
      case String.split(str, "=", parts: 2) do
        [key, value] ->
          key_atom = String.to_atom(key)
          parsed_value = parse_value(value)
          Map.put(acc, key_atom, parsed_value)

        _ ->
          acc
      end
    end)
  end

  defp parse_value(value) do
    cond do
      Regex.match?(~r/^\d+$/, value) -> String.to_integer(value)
      Regex.match?(~r/^\d+\.\d+$/, value) -> String.to_float(value)
      String.downcase(value) == "true" -> true
      String.downcase(value) == "false" -> false
      true -> value
    end
  end
end
