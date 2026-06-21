defmodule LabWeb.RunLive do
  use LabWeb, :live_view

  @moduledoc """
  Run an experiment with custom parameters. Shows live charts during
  execution and assertion results at completion.

  Phase 2 (commit 14) fills in the parameter form and execution logic.
  """

  @impl true
  def mount(%{"id" => exp_id}, _session, socket) do
    {:ok, assign(socket, :experiment_id, exp_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Run <%= @experiment_id %></h2>
    <p>Parameter form and live execution land in Phase 2 (commit 14).</p>
    <p><a href="/catalog">← Back to catalog</a></p>
    """
  end
end
