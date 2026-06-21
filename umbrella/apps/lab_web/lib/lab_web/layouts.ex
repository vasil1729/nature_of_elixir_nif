defmodule LabWeb.Layouts do
  @moduledoc false
  use LabWeb, :html

  embed_templates "layouts/*"

  def nav_links do
    [
      %{label: "Dashboard", path: "/", icon: "chart"},
      %{label: "Catalog", path: "/catalog", icon: "list"},
      %{label: "History", path: "/history", icon: "clock"},
      %{label: "Docs", path: "/docs", icon: "book"}
    ]
  end
end
