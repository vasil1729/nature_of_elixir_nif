defmodule LabWeb.DocsLive do
  use LabWeb, :live_view

  @moduledoc """
  Browse docs/*.md in-browser.

  Phase 2 (commit 15) fills in the docs browser with markdown rendering.
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :docs, list_docs())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Documentation</h2>
    <p>Browse lab documentation in-browser. Phase 2 (commit 15) adds markdown rendering.</p>

    <ul>
      <%= for doc <- @docs do %>
        <li><a href={"/docs/#{doc}"}><%= doc %></a></li>
      <% end %>
    </ul>
    """
  end

  defp list_docs do
    ["00_charter", "01_beam_scheduler_model", "02_nif_taxonomy_rustler",
     "03_measurement_protocol", "04_experiment_catalog", "05_safety_isolation",
     "06_reproducibility_protocol", "07_ui_architecture", "08_final_report_rubric",
     "09_architecture", "10_development_guide", "11_commit_convention",
     "12_glossary", "13_runbook"]
  end
end
