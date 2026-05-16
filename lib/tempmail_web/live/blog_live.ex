defmodule TempmailWeb.BlogLive do
  use TempmailWeb, :live_view

  alias Tempmail.Content

  @impl true
  def mount(params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    {:ok,
     socket
     |> assign(:page_title, "Blog")
     |> assign(:locale, locale)
     |> assign(:posts, Content.list_published_posts(locale))}
  end
end
