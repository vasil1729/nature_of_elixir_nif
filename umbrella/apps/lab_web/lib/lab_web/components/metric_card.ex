defmodule LabWeb.Components.MetricCard do
  @moduledoc """
  Renders a single metric as a card with label, value, and unit.
  """

  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :unit, :string, default: ""
  attr :trend, :string, default: nil

  def metric_card(assigns) do
    ~H"""
    <div class="metric-card">
      <div class="metric-label"><%= @label %></div>
      <div class="metric-value"><%= format_value(@value) %> <small><%= @unit %></small></div>
      <%= if @trend do %>
        <div class="metric-trend"><%= @trend %></div>
      <% end %>
    </div>
    """
  end

  defp format_value(nil), do: "—"
  defp format_value(v) when is_float(v), do: Float.round(v, 2)
  defp format_value(v), do: v
end
