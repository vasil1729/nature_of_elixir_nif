defmodule LabWeb.Components.SchedulerBar do
  @moduledoc """
  Renders a per-scheduler utilization bar with smooth transitions.
  """

  use Phoenix.Component

  attr :schedulers, :list, required: true, doc: "list of {id, util} tuples"
  attr :label, :string, default: "Schedulers"
  attr :kind, :atom, default: :normal, doc: ":normal | :dirty_cpu | :dirty_io"

  def scheduler_bar(assigns) do
    ~H"""
    <div class="scheduler-bars">
      <h4><%= @label %></h4>
      <%= for {id, util} <- @schedulers do %>
        <div class="scheduler-bar" id={"scheduler-bar-#{id}"} phx-update="ignore">
          <span class="scheduler-id"><%= "S#{id}" %></span>
          <div class="scheduler-bar-track">
            <div class={"scheduler-bar-fill #{bar_class(util, @kind)}"}
                 style={"width: #{trunc(util * 100)}%; transition: width 0.3s ease;"}>
            </div>
          </div>
          <span class="scheduler-pct"><%= Float.round(util * 100, 1) %>%</span>
        </div>
      <% end %>
    </div>
    """
  end

  defp bar_class(util, _kind) when util >= 0.99, do: "blocked"
  defp bar_class(_util, :dirty_cpu), do: "dirty-cpu"
  defp bar_class(_util, :dirty_io), do: "dirty-io"
  defp bar_class(_util, :normal), do: "normal"
end
