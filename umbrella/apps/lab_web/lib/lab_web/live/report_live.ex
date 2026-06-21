defmodule LabWeb.ReportLive do
  use LabWeb, :live_view

  @moduledoc """
  Browse generated report.md per experiment + the final 14-question report.

  Phase 2 (commit 15) fills in the report viewer.
  """

  @impl true
  def mount(%{"id" => id}, _session, socket) when id != "final" do
    {:ok, assign(socket, :report_id, id)}
  end

  def mount(%{"path" => "final"}, _session, socket) do
    {:ok, assign(socket, :report_id, "final")}
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :report_id, "final")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Report: <%= @report_id %></h2>
    <p>Report viewer. Phase 2 (commit 15) renders markdown in-browser.</p>
    """
  end
end
