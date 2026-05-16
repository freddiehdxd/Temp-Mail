defmodule TempmailWeb.DashboardSettingsLive do
  use TempmailWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:locale, Map.get(params, "locale", "en"))}
  end
end
