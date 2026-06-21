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
      |> assign(:started_at, nil)
      |> assign(:elapsed_ms, 0)

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
          <button type="submit" disabled={@running} class={if @running, do: "running"}>
            <%= if @running, do: "⏳ Running...", else: "▶ Run Experiment" %>
          </button>
        </form>
      <% else %>
        <form phx-submit="run">
          <button type="submit" disabled={@running} class={if @running, do: "running"}>
            <%= if @running, do: "⏳ Running...", else: "▶ Run Experiment" %>
          </button>
        </form>
      <% end %>

      <%= if @running do %>
        <div class="run-progress">
          <div class="progress-header">
            <span class="spinner"></span>
            <span>Experiment running...</span>
            <span class="elapsed">Elapsed: <%= format_elapsed(@elapsed_ms) %></span>
          </div>

          <h3>Live Metrics</h3>
          <div class="metric-grid">
            <.metric_card label="Run Queue" value={@live_sampler && @live_sampler.run_queue || "—"} status={rq_status(@live_sampler && @live_sampler.run_queue)} />
            <.metric_card label="Processes" value={@live_sampler && @live_sampler.process_count || "—"} />
            <.metric_card label="BEAM Mem (MB)" value={@live_sampler && @live_sampler.beam_memory_mb || "—"} />
            <.metric_card label="Latency p99 (ms)" value={@live_latency && @live_latency[:p99_us] && Float.round(@live_latency.p99_us / 1000, 2) || "—"} status={lat_status(@live_latency && @live_latency[:p99_us])} />
          </div>

          <div class="scheduler-mini" style="margin-top: 1rem;">
            <h4>Normal Schedulers</h4>
            <div class="scheduler-bars">
              <%= for {id, util} <- @live_sampler && @live_sampler.sched_util || [] do %>
                <div class="scheduler-bar" id={"mini-bar-#{id}"} phx-update="ignore">
                  <span class="scheduler-id"><%= "S#{id}" %></span>
                  <div class="scheduler-bar-track">
                    <div class={"scheduler-bar-fill #{bar_class(util, :normal)}"}
                         style={"width: #{trunc(util * 100)}%; transition: width 0.3s ease;"}>
                    </div>
                  </div>
                  <span class="scheduler-pct"><%= Float.round(util * 100, 1) %>%</span>
                </div>
              <% end %>
            </div>
          </div>
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
          <strong>Duration:</strong> <%= format_elapsed(@result.work_result.duration_ms || @elapsed_ms) %> |
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
                  <%= if passed?, do: "✅ PASS", else: "❌ FAIL" %>
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
    started_at = System.monotonic_time(:millisecond)

    socket = socket
      |> assign(:running, true)
      |> assign(:error, nil)
      |> assign(:result, nil)
      |> assign(:live_metrics, [])
      |> assign(:started_at, started_at)
      |> assign(:elapsed_ms, 0)

    # Start elapsed timer
    if connected?(socket) do
      :timer.send_interval(500, :tick_elapsed)
    end

    # Run in a task so the LiveView process doesn't block
    Task.Supervisor.async_nolink(LabWeb.TaskSupervisor, fn ->
      Lab.Runner.run(String.to_atom(exp_id), params: parsed)
    end)

    {:noreply, assign(socket, :params, parsed)}
  end

  @impl true
  def handle_info({ref, {:ok, result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, socket |> assign(:running, false) |> assign(:result, result)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    {:noreply, socket |> assign(:running, false) |> assign(:error, "Task crashed: #{inspect(reason)}")}
  end

  def handle_info(:tick_elapsed, socket) do
    if socket.assigns.running and socket.assigns.started_at do
      elapsed = System.monotonic_time(:millisecond) - socket.assigns.started_at
      {:noreply, assign(socket, :elapsed_ms, elapsed)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:sampler, metrics, _meta}, socket) do
    m = %{
      run_queue: metrics.run_queue || 0,
      process_count: metrics.process_count || 0,
      beam_memory_mb: div(metrics.beam_total_memory || 0, 1024 * 1024),
      sched_util: metrics.sched_util || [],
      dirty_cpu_util: metrics.dirty_cpu_util || [],
      dirty_io_util: metrics.dirty_io_util || []
    }
    {:noreply, assign(socket, :live_sampler, m)}
  end

  def handle_info({:latency_window, metrics, _meta}, socket) do
    {:noreply, assign(socket, :live_latency, metrics)}
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

  # -- Template helpers --

  defp format_elapsed(ms) do
    s = div(ms, 1000)
    if s < 60, do: "#{s}s", else: "#{div(s, 60)}m #{rem(s, 60)}s"
  end

  defp rq_status(q) when is_number(q) and q > 10, do: :danger
  defp rq_status(q) when is_number(q) and q > 3, do: :warn
  defp rq_status(_), do: :good

  defp lat_status(nil), do: :neutral
  defp lat_status(v) when is_number(v) and v > 50, do: :danger
  defp lat_status(v) when is_number(v) and v > 10, do: :warn
  defp lat_status(_), do: :good

  defp bar_class(util, _kind) when util >= 0.99, do: "blocked"
  defp bar_class(_util, :dirty_cpu), do: "dirty-cpu"
  defp bar_class(_util, :dirty_io), do: "dirty-io"
  defp bar_class(_util, :normal), do: "normal"
end
