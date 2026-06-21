defmodule LabWeb.DashboardLive do
  use LabWeb, :live_view

  @moduledoc """
  Real-time BEAM health dashboard.

  Shows per-scheduler utilization, run queue, process count, memory, and
  latency p50/p99/max. Updates in real time via Phoenix.PubSub
  subscription to the \"lab:metrics\" topic.

  Phase 2 (commit 13) fills in the full implementation with live telemetry.
  This stub renders a static placeholder.
  """

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Lab.PubSub, Lab.Core.TelemetryPub.topic())
    end

    socket =
      socket
      |> assign(:schedulers, sample_schedulers())
      |> assign(:run_queue, 0)
      |> assign(:process_count, :erlang.system_info(:process_count))
      |> assign(:memory, :erlang.memory(:total))
      |> assign(:latency_window, nil)
      |> assign(:last_update, System.monotonic_time(:millisecond))

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Dashboard</h2>
    <p>BEAM health at a glance. When an experiment runs, this page shows
    live scheduler utilization, latency, and memory.</p>

    <div class="metric-grid">
      <.metric_card label="Process Count" value={@process_count} />
      <.metric_card label="Run Queue" value={@run_queue} />
      <.metric_card label="Memory" value={div(@memory, 1024 * 1024)} unit="MB" />
      <.metric_card label="Last Update" value={@last_update} />
    </div>

    <.scheduler_bar schedulers={@schedulers} label="Normal Schedulers" kind={:normal} />

    <p><small>Full live implementation lands in Phase 2 (commit 13).</small></p>
    """
  end

  @impl true
  def handle_info({:sampler, metrics, _meta}, socket) do
    {:noreply,
     socket
     |> assign(:schedulers, metrics.sched_util || [])
     |> assign(:run_queue, metrics.run_queue || 0)
     |> assign(:process_count, metrics.process_count || 0)
     |> assign(:memory, metrics.beam_total_memory || 0)
     |> assign(:last_update, System.monotonic_time(:millisecond))}
  end

  def handle_info({:latency_window, metrics, _meta}, socket) do
    {:noreply, assign(socket, :latency_window, metrics)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp sample_schedulers do
    count = :erlang.system_info(:schedulers)
    Enum.map(1..count, fn id -> {id, 0.0} end)
  end
end
