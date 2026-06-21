defmodule LabWeb.HistoryLive do
  use LabWeb, :live_view

  @moduledoc """
  Past runs table with side-by-side comparison.

  Reads from data/ directory to list runs that have been executed.
  Phase 4 will add Postgres-backed history when the Repo is wired.
  """

  @impl true
  def mount(_params, _session, socket) do
    runs = list_runs()
    {:ok, assign(socket, :runs, runs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Run History</h2>
    <p>Past experiment runs and their results. Click an experiment to view its report.</p>

    <%= if @runs == [] do %>
      <p><em>No runs yet. Run an experiment from the <a href="/catalog">catalog</a>.</em></p>
    <% else %>
      <table>
        <thead>
          <tr>
            <th>Experiment</th>
            <th>Data Directory</th>
            <th>Files</th>
            <th>Report</th>
          </tr>
        </thead>
        <tbody>
          <%= for run <- @runs do %>
            <tr>
              <td><strong><%= run.id %></strong></td>
              <td><code><%= run.path %></code></td>
              <td><%= run.file_count %></td>
              <td><a href={"/reports/#{run.id}"}>View →</a></td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% end %>
    """
  end

  defp list_runs do
    "data/e*"
    |> Path.wildcard()
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(fn path ->
      id = path |> Path.basename() |> String.upcase()
      files = Path.wildcard(Path.join(path, "*.jsonl"))
      %{id: id, path: path, file_count: length(files)}
    end)
    |> Enum.sort_by(& &1.id)
  end
end
