defmodule LabWeb do
  @moduledoc """
  The entry point for LabWeb's web interface.

  Use this module to import common functions for LiveView and components.
  """

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json]

      import Plug.Conn
      import LabWeb.Gettext
      alias LabWeb.Router.Helpers, as: Routes
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Component

      import LabWeb.Gettext
      alias LabWeb.Router.Helpers, as: Routes
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {LabWeb.Layouts, :app}

      import Phoenix.Component

      import LabWeb.Gettext
      alias LabWeb.Router.Helpers, as: Routes

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      import Phoenix.Component

      import LabWeb.Gettext
      alias LabWeb.Router.Helpers, as: Routes

      unquote(html_helpers())
    end
  end

  def component do
    quote do
      use Phoenix.Component

      import Phoenix.Component

      import LabWeb.Gettext
      alias LabWeb.Router.Helpers, as: Routes

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import LabWeb.Components.SchedulerBar
      import LabWeb.Components.MetricCard
      import LabWeb.Components.LatencyChart
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
