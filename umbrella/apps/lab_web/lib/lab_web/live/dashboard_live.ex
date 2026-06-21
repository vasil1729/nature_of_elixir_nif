defmodule LabWeb.DashboardLive do
  use LabWeb, :live_view

  @moduledoc """
  Real-time BEAM health dashboard.

  Shows per-scheduler utilization, run queue, process count, memory, and
  latency p50/p99/max. Updates in real time via Phoenix.PubSub
  subscription to the \"lab:metrics\" topic.

  **When the dashboard freezes during E01**, that's the evidence — the
  scheduler running the LiveView process is blocked by the NIF. A banner
  appears on resume explaining the freeze was the experiment.
  See docs/07_ui_architecture.md.
  """

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Lab.PubSub, Lab.Core.TelemetryPub.topic())
    end

    now = System.monotonic_time(:millisecond)

    socket =
      socket
      |> assign(:schedulers, init_schedulers())
      |> assign(:dirty_cpu_schedulers, init_dirty(:dirty_cpu_schedulers))
      |> assign(:dirty_io_schedulers, init_dirty(:dirty_io_schedulers))
      |> assign(:run_queue, 0)
      |> assign(:process_count, :erlang.system_info(:process_count))
      |> assign(:beam_memory, :erlang.memory(:total))
      |> assign(:beam_binary_memory, :erlang.memory(:binary))
      |> assign(:latency_window, nil)
      |> assign(:latency_history, [])
      |> assign(:rss_kb, nil)
      |> assign(:threads, nil)
      |> assign(:watchdog_events, [])
      |> assign(:last_update, now)
      |> assign(:frozen_since, nil)
      |> assign(:scheduler_count, :erlang.system_info(:schedulers))
      |> assign(:dirty_cpu_count, :erlang.system_info(:dirty_cpu_schedulers))
      |> assign(:dirty_io_count, :erlang.system_info(:dirty_io_schedulers))

    # Check for freeze every 2 seconds
    if connected?(socket) do
      :timer.send_interval(2000, :check_frozen)
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Dashboard</h2>
    <p>BEAM health at a glance. When an experiment runs, this page shows
    live scheduler utilization, latency, and memory.</p>

    <%= if @frozen_since do %>
      <div class="banner danger">
        <strong>⚠ Scheduler appears blocked.</strong>
        The dashboard hasn't received metrics in <%= div(System.monotonic_time(:millisecond) - @frozen_since, 1000) %>s.
        If an experiment is running, this freeze IS the evidence — a normal NIF
        is blocking a scheduler. The dashboard will resume when the NIF returns.
      </div>
    <% end %>

    <div class="metric-grid">
      <.metric_card label="Process Count" value={@process_count} />
      <.metric_card label="Run Queue" value={@run_queue} />
      <.metric_card label="Memory" value={div(@beam_memory, 1024 * 1024)} unit="MB" />
      <.metric_card label="Binary Memory" value={div(@beam_binary_memory, 1024 * 1024)} unit="MB" />
      <.metric_card label="RSS" value={if @rss_kb, do: div(@rss_kb, 1024), else: "—"} unit="MB" />
      <.metric_card label="Threads" value={@threads || "—"} />
      <.metric_card label="Schedulers" value={@scheduler_count} />
      <.metric_card label="Dirty CPU" value={@dirty_cpu_count} />
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 2rem;">
      <div>
        <.scheduler_bar schedulers={@schedulers} label="Normal Schedulers" kind={:normal} />
      </div>
      <div>
        <.scheduler_bar schedulers={@dirty_cpu_schedulers} label="Dirty CPU Schedulers" kind={:dirty_cpu} />
        <.scheduler_bar schedulers={@dirty_io_schedulers} label="Dirty IO Schedulers" kind={:dirty_io} />
      </div>
    </div>

    <%= if @latency_window do %>
      <h3>Latency</h3>
      <div class="metric-grid">
        <.metric_card label="p50" value={if @latency_window[:p50_us], do: Float.round(@latency_window.p50_us / 1000, 2), else: "—"} unit="ms" />
        <.metric_card label="p99" value={if @latency_window[:p99_us], do: Float.round(@latency_window.p99_us / 1000, 2), else: "—"} unit="ms" />
        <.metric_card label="max" value={if @latency_window[:max_us], do: Float.round(@latency_window.max_us / 1000, 2), else: "—"} unit="ms" />
        <.metric_card label="samples" value={@latency_window[:count] || 0} />
      </div>
    <% end %>

    <%= if @watchdog_events != [] do %>
      <h3>Watchdog Events</h3>
      <ul>
        <%= for event <- Enum.take(@watchdog_events, -10) do %>
          <li><code><%= event.event %></code> <%= inspect(event.detail) %></li>
        <% end %>
      </ul>
    <% end %>

    <p><small>Last update: <%= @last_update %></small></p>
    """
  end

  # -- Telemetry handlers --

  @impl true
  def handle_info({:sampler, metrics, _meta}, socket) do
    now = System.monotonic_time(:millisecond)

    {:noreply,
     socket
     |> assign(:schedulers, metrics.sched_util || [])
     |> assign(:dirty_cpu_schedulers, metrics.dirty_cpu_util || [])
     |> assign(:dirty_io_schedulers, metrics.dirty_io_util || [])
     |> assign(:run_queue, metrics.run_queue || 0)
     |> assign(:process_count, metrics.process_count || 0)
     |> assign(:beam_memory, metrics.beam_total_memory || 0)
     |> assign(:beam_binary_memory, metrics.beam_binary_memory || 0)
     |> assign(:last_update, now)
     |> assign(:frozen_since, nil)}
  end

  def handle_info({:latency_window, metrics, _meta}, socket) do
    history = [metrics | socket.assigns.latency_history] |> Enum.take(100)
    {:noreply, assign(socket, :latency_window, metrics) |> assign(:latency_history, history)}
  end

  def handle_info({:latency, _metrics, _meta}, socket) do
    {:noreply, socket}
  end

  def handle_info({:system, metrics, _meta}, socket) do
    {:noreply,
     socket
     |> assign(:rss_kb, metrics.rss_kb)
     |> assign(:threads, metrics.threads)}
  end

  def handle_info({:watchdog, metrics, _meta}, socket) do
    events = [metrics | socket.assigns.watchdog_events] |> Enum.take(20)
    {:noreply, assign(socket, :watchdog_events, events)}
  end

  def handle_info(:check_frozen, socket) do
    now = System.monotonic_time(:millisecond)
    last = socket.assigns.last_update

    frozen_since =
      cond do
        now - last > 3000 and is_nil(socket.assigns.frozen_since) -> last
        now - last <= 3000 -> nil
        true -> socket.assigns.frozen_since
      end

    {:noreply, assign(socket, :frozen_since, frozen_since)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # -- Helpers --

  defp init_schedulers do
    count = :erlang.system_info(:schedulers)
    Enum.map(1..count, fn id -> {id, 0.0} end)
  end

  defp init_dirty(info_key) do
    count = :erlang.system_info(info_key)
    base = :erlang.system_info(:schedulers)
    Enum.map(1..count, fn id -> {base + id, 0.0} end)
  end
end
