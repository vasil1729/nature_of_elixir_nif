defmodule LabWeb.RunLive do
  use LabWeb, :live_view

  @moduledoc """
  Run an experiment with custom parameters. Shows live charts during
  execution and assertion results at completion.

  For crash experiments (mode: :isolated), the workload runs in a child
  BEAM — the UI stays alive to record the death.
  For non-crash experiments (mode: :in_process), the workload runs in
  the UI's BEAM. The dashboard may freeze — that's evidence.
  """

  @impl true
  def mount(%{"id" => exp_id}, _session, socket) do
    config = load_config(exp_id)

    socket =
      socket
      |> assign(:experiment_id, exp_id)
      |> assign(:config, config)
      |> assign(:params, default_params(config))
      |> assign(:running, false)
      |> assign(:result, nil)
      |> assign(:error, nil)
      |> assign(:live_metrics, [])

    if connected?(socket) and config != nil do
      Phoenix.PubSub.subscribe(Lab.PubSub, Lab.Core.TelemetryPub.topic())
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Run <%= @experiment_id %></h2>

    <%= if @config == nil do %>
      <p>Experiment not found. <a href="/catalog">← Back to catalog</a></p>
    <% else %>
      <p><a href="/catalog">← Back to catalog</a></p>

      <h3>Hypothesis</h3>
      <p><%= @config[:hypothesis] || "(not declared)" %></p>

      <%= if @config[:mode] == :isolated do %>
        <div class="banner">
          <strong>Crash experiment (isolated mode).</strong>
          This experiment runs in a child BEAM. If it crashes, the UI survives
          and records the death.
        </div>
      <% end %>

      <h3>Parameters</h3>
      <%= if @config[:params] && map_size(@config[:params]) > 0 do %>
        <form phx-submit="run">
          <%= for {key, spec} <- @config[:params] do %>
            <label>
              <%= spec[:label] || key %>
              <input type="number"
                     name={"param_#{key}"}
                     value={@params[key] || spec[:default]}
                     min={spec[:min]}
                     max={spec[:max]}
                     disabled={@running} />
            </label>
          <% end %>
          <button type="submit" disabled={@running}>
            <%= if @running, do: "Running...", else: "Run Experiment" %>
          </button>
        </form>
      <% else %>
        <form phx-submit="run">
          <button type="submit" disabled={@running}>
            <%= if @running, do: "Running...", else: "Run Experiment" %>
          </button>
        </form>
      <% end %>

      <%= if @running do %>
        <h3>Live Metrics</h3>
        <div class="metric-grid">
          <%= for metric <- Enum.take(@live_metrics, -5) do %>
            <div class="metric-card">
              <div class="metric-label"><%= metric.label %></div>
              <div class="metric-value"><%= metric.value %></div>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @error do %>
        <div class="banner danger">
          <strong>Error:</strong> <%= @error %>
        </div>
      <% end %>

      <%= if @result do %>
        <h3>Results</h3>
        <div class={"banner #{if @result.assertion_fail > 0, do: "danger"}"}>
          <strong>Exit code:</strong> <%= @result.exit_code %> |
          <strong>Assertions:</strong> <%= @result.assertion_pass %> pass, <%= @result.assertion_fail %> fail
        </div>

        <h4>Assertion Details</h4>
        <table>
          <thead>
            <tr><th>Assertion</th><th>Result</th></tr>
          </thead>
          <tbody>
            <%= for {key, passed?} <- @result.assertions do %>
              <tr>
                <td><code><%= key %></code></td>
                <td class={"assertion-#{if passed?, do: "pass", else: "fail"}"}>
                  <%= if passed?, do: "PASS", else: "FAIL" %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <p><a href={"/reports/#{@experiment_id}"}>View full report →</a></p>
      <% end %>
    <% end %>
    """
  end

  @impl true
  def handle_event("run", params, socket) do
    config = socket.assigns.config
    parsed = parse_form_params(params, config)
    exp_id = socket.assigns.experiment_id

    socket = assign(socket, :running, true) |> assign(:error, nil) |> assign(:result, nil) |> assign(:live_metrics, [])

    # Run in a task so the LiveView process doesn't block
    Task.Supervisor.async_nolink(LabWeb.TaskSupervisor, fn ->
      Lab.Runner.run(String.to_atom(exp_id), params: parsed)
    end)

    {:noreply, assign(socket, :params, parsed)}
  end

  @impl true
  def handle_info({ref, {:ok, result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, assign(socket, :running, false) |> assign(:result, result)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    {:noreply, assign(socket, :running, false) |> assign(:error, "Task crashed: #{inspect(reason)}")}
  end

  def handle_info({:sampler, metrics, _meta}, socket) do
    live_metrics = socket.assigns.live_metrics ++ [
      %{label: "Run Queue", value: metrics.run_queue},
      %{label: "Processes", value: metrics.process_count},
      %{label: "Memory", value: div(metrics.beam_total_memory || 0, 1024 * 1024)}
    ]
    {:noreply, assign(socket, :live_metrics, Enum.take(live_metrics, -20))}
  end

  def handle_info({:latency_window, metrics, _meta}, socket) do
    live_metrics = socket.assigns.live_metrics ++ [
      %{label: "Latency p99", value: if(metrics[:p99_us], do: Float.round(metrics.p99_us / 1000, 2), else: "—")}
    ]
    {:noreply, assign(socket, :live_metrics, Enum.take(live_metrics, -20))}
  end

  def handle_info(_, socket), do: {:noreply, socket}

  defp load_config(exp_id) do
    try do
      Lab.ExperimentConfig.load!(exp_id)
    rescue
      _ -> nil
    end
  end

  defp default_params(nil), do: %{}
  defp default_params(config) do
    config
    |> Map.get(:params, %{})
    |> Map.new(fn {key, spec} -> {key, spec[:default]} end)
  end

  defp parse_form_params(params, config) do
    config_params = Map.get(config, :params, %{})

    Enum.reduce(config_params, %{}, fn {key, spec}, acc ->
      form_key = "param_#{key}"
      value = params[form_key] || to_string(spec[:default] || "")
      Map.put(acc, key, parse_value(value, spec))
    end)
  end

  defp parse_value(value, _spec) when is_binary(value) do
    case Integer.parse(value) do
      {n, _} -> n
      :error ->
        case Float.parse(value) do
          {f, _} -> f
          :error -> value
        end
    end
  end

  defp parse_value(value, _spec), do: value
end
