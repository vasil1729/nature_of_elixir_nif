defmodule LabWeb.Components.SchedulerBar do
  @moduledoc """
  Renders a per-scheduler utilization bar.

  Each scheduler gets a horizontal bar showing its utilization (0-100%).
  Normal schedulers are green; dirty CPU schedulers are orange; dirty IO
  schedulers are blue. Blocked schedulers (100% for > 1s) turn red.
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
        <div class="scheduler-bar">
          <span style="width: 30px;"><%= id %></span>
          <div class={"scheduler-bar-fill #{bar_class(util, @kind)}"}
               style={"width: #{trunc(util * 100)}px;"}>
          </div>
          <span><%= Float.round(util * 100, 1) %>%</span>
        </div>
      <% end %>
    </div>
    """
  end

  defp bar_class(util, _kind) when util >= 0.99, do: "blocked"
  defp bar_class(_util, :dirty_cpu), do: "dirty"
  defp bar_class(_util, :dirty_io), do: "dirty"
  defp bar_class(_util, :normal), do: ""
end
