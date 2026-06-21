defmodule LabWeb.ReportLive do
  use LabWeb, :live_view

  @moduledoc """
  Browse generated report.md per experiment + the final 14-question report.

  Reads the report.md file from the experiment directory and renders it
  as preformatted text (full markdown rendering would require an external
  library; preformatted is sufficient for a research lab).
  """

  @impl true
  def mount(%{"id" => id}, _session, socket) when id != "final" do
    report = load_experiment_report(id)
    {:ok, socket |> assign(:report_id, id) |> assign(:report_content, report) |> assign(:is_final, false)}
  end

  def mount(%{"path" => "final"}, _session, socket) do
    report = load_final_report()
    {:ok, socket |> assign(:report_id, "final") |> assign(:report_content, report) |> assign(:is_final, true)}
  end

  def mount(_params, _session, socket) do
    report = load_final_report()
    {:ok, socket |> assign(:report_id, "final") |> assign(:report_content, report) |> assign(:is_final, true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2><%= if @is_final, do: "Final Report", else: "Report: #{@report_id}" %></h2>

    <%= if @report_content do %>
      <pre style="white-space: pre-wrap; font-family: monospace;"><%= @report_content %></pre>
    <% else %>
      <p><em>No report found for <%= @report_id %>.</em></p>
      <p>Run the experiment first: <a href={"/catalog/#{@report_id}/run"}>Run <%= @report_id %> →</a></p>
    <% end %>

    <p><a href="/history">← Back to history</a></p>
    """
  end

  defp load_experiment_report(exp_id) do
    "experiments/#{exp_id}_*/report.md"
    |> Path.wildcard()
    |> List.first()
    |> case do
      nil -> nil
      path -> File.read(path)
    end
    |> case do
      {:ok, content} -> content
      nil -> nil
    end
  end

  defp load_final_report do
    "reports/FINAL_REPORT.md"
    |> File.read()
    |> case do
      {:ok, content} -> content
      _ -> nil
    end
  end
end
