defmodule LabWeb.CatalogLive do
  use LabWeb, :live_view

  @moduledoc """
  Browse all 21 experiments: hypothesis, params, tags, status, links.

  Reads from the experiments/ directory to discover available experiments.
  Links to the Run page for each.
  """

  @impl true
  def mount(_params, _session, socket) do
    experiments = list_experiments()
    {:ok, assign(socket, :experiments, experiments)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Experiment Catalog</h2>
    <p>All 21 experiments. Click an experiment to run it with custom parameters.</p>

    <table>
      <thead>
        <tr>
          <th>ID</th>
          <th>Name</th>
          <th>Theme</th>
          <th>Mode</th>
          <th>Tags</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <%= for exp <- @experiments do %>
          <tr>
            <td><strong><%= exp.id %></strong></td>
            <td><%= exp.name %></td>
            <td><small><%= exp.theme %></small></td>
            <td><code><%= exp.mode %></code></td>
            <td><%= Enum.join(exp.tags, " ") %></td>
            <td><a href={"/catalog/#{exp.id}/run"}>Run →</a></td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp list_experiments do
    [
      %{id: "E01", name: "CPU-bound Normal NIF", theme: "A — Scheduler Blocking", tags: ["@slow"], mode: "in_process"},
      %{id: "E02", name: "CPU-bound Dirty NIF", theme: "A", tags: ["@slow"], mode: "in_process"},
      %{id: "E03", name: "Infinite Loop", theme: "A", tags: ["@crash", "@slow"], mode: "isolated"},
      %{id: "E04", name: "Sleeping Normal NIF", theme: "A", tags: ["@slow"], mode: "in_process"},
      %{id: "E05", name: "Sleeping Dirty NIF", theme: "A", tags: ["@slow"], mode: "in_process"},
      %{id: "E06", name: "Network Wait", theme: "A", tags: ["@slow"], mode: "in_process"},
      %{id: "E07", name: "Filesystem Stall", theme: "A", tags: ["@slow"], mode: "in_process"},
      %{id: "E08", name: "Rust Panic", theme: "B — Failure Modes", tags: ["@crash"], mode: "isolated"},
      %{id: "E09", name: "Native Memory Leak", theme: "B", tags: ["@slow"], mode: "in_process"},
      %{id: "E10", name: "Resource Leak", theme: "B", tags: ["@slow"], mode: "in_process"},
      %{id: "E11", name: "Mutex Deadlock", theme: "B", tags: ["@crash", "@slow"], mode: "isolated"},
      %{id: "E12", name: "Thread Explosion", theme: "B", tags: ["@slow"], mode: "in_process"},
      %{id: "E13", name: "Detached Native Thread", theme: "B", tags: ["@slow"], mode: "in_process"},
      %{id: "E14", name: "Native Library Failure", theme: "B", tags: ["@crash"], mode: "isolated"},
      %{id: "E15", name: "Caller Dies Mid-Execution", theme: "C — Lifecycle", tags: ["@slow"], mode: "in_process"},
      %{id: "E16", name: "Node Shutdown During Work", theme: "C", tags: ["@crash", "@slow"], mode: "isolated"},
      %{id: "E17", name: "Port vs NIF vs Dirty", theme: "C", tags: ["@slow"], mode: "in_process"},
      %{id: "E18", name: "Large Binary Transfer", theme: "D — Scale", tags: ["@slow"], mode: "in_process"},
      %{id: "E19", name: "Scheduler Saturation Curve", theme: "D", tags: ["@slow"], mode: "in_process"},
      %{id: "E20", name: "Oban Interaction", theme: "E — Real-World", tags: ["@slow", "@oban"], mode: "in_process"},
      %{id: "E21", name: "Real PDF Workload", theme: "E", tags: ["@slow", "@oban", "@pdf"], mode: "in_process"}
    ]
  end
end
