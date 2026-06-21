defmodule LabWeb.HistoryLive do
  use LabWeb, :live_view

  @moduledoc """
  Past runs table with side-by-side comparison.

  Phase 2 (commit 15) fills in the full history with Postgres queries.
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :runs, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Run History</h2>
    <p>Past runs and comparison. Phase 2 (commit 15) fills in Postgres-backed history.</p>
    <%= if @runs == [] do %>
      <p><em>No runs yet. Run an experiment from the <a href="/catalog">catalog</a>.</em></p>
    <% end %>
    """
  end
end
