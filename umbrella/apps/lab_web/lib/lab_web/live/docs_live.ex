defmodule LabWeb.DocsLive do
  use LabWeb, :live_view

  @moduledoc """
  Browse docs/*.md in-browser.

  Lists all documentation files and renders the selected one as
  preformatted text. Full markdown rendering would require an external
  library; preformatted is sufficient for a research lab.
  """

  @impl true
  def mount(%{"path" => path}, _session, socket) do
    doc_path = if is_list(path), do: Path.join(path), else: path
    content = load_doc(doc_path)
    {:ok, socket |> assign(:docs, list_docs()) |> assign(:selected, doc_path) |> assign(:content, content)}
  end

  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:docs, list_docs()) |> assign(:selected, nil) |> assign(:content, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <h2>Documentation</h2>

    <div style="display: grid; grid-template-columns: 250px 1fr; gap: 2rem;">
      <div>
        <ul>
          <%= for doc <- @docs do %>
            <li><a href={"/docs/#{doc}"}><%= doc %></a></li>
          <% end %>
          <li><a href="/docs/adr">ADR index</a></li>
        </ul>
      </div>
      <div>
        <%= if @content do %>
          <h3><%= @selected %></h3>
          <div style="max-width: 900px;"><%= if @content, do: Phoenix.HTML.raw(@content), else: "" %></div>
        <% else %>
          <p>Select a document from the left.</p>
          <p>Full documentation index: <a href="/docs/INDEX">docs/INDEX.md</a></p>
        <% end %>
      </div>
    </div>
    """
  end

  defp list_docs do
    ~w(00_charter 01_beam_scheduler_model 02_nif_taxonomy_rustler
       03_measurement_protocol 04_experiment_catalog 05_safety_isolation
       06_reproducibility_protocol 07_ui_architecture 08_final_report_rubric
       09_architecture 10_development_guide 11_commit_convention
       12_glossary 13_runbook)
  end

  defp load_doc("adr") do
    candidate = Path.join(docs_root(), "adr/README.md")
    case File.read(candidate) do
      {:ok, content} -> render_markdown(content)
      _ -> nil
    end
  end

  defp load_doc(path) do
    candidate = Path.join(docs_root(), "#{path}.md")
    case File.read(candidate) do
      {:ok, content} -> render_markdown(content)
      _ -> nil
    end
  end

  defp render_markdown(text) do
    case Earmark.as_html(text, %Earmark.Options{compact_output: true}) do
      {:ok, html, _} -> html
      _ -> "<pre>#{text}</pre>"
    end
  end

  defp docs_root do
    if File.dir?("docs") do
      "docs"
    else
      "../docs"
    end
  end
end
