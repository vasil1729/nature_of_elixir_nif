defmodule LabWeb.Components.MetricCard do
  @moduledoc """
  Renders a single metric as a card with label, value, unit, and optional status color.
  """

  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :unit, :string, default: ""
  attr :trend, :string, default: nil
  attr :status, :atom, default: :neutral, doc: ":good | :warn | :danger | :neutral"

  def metric_card(assigns) do
    ~H"""
    <div class={"metric-card #{status_class(@status)}"}>
      <div class="metric-label"><%= @label %></div>
      <div class="metric-value">
        <%= format_value(@value) %>
        <small><%= @unit %></small>
      </div>
      <%= if @trend do %>
        <div class="metric-trend"><%= @trend %></div>
      <% end %>
    </div>
    """
  end

  defp format_value(nil), do: "—"
  defp format_value(v) when is_float(v), do: Float.round(v, 2)
  defp format_value(v), do: v

  defp status_class(:good), do: "status-good"
  defp status_class(:warn), do: "status-warn"
  defp status_class(:danger), do: "status-danger"
  defp status_class(_), do: ""
end
