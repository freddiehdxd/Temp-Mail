defmodule TempmailWeb.StaticPageLive do
  use TempmailWeb, :live_view

  @copy %{
    about:
      {"About",
       "TempMail Central provides disposable and permanent inboxes for privacy-conscious workflows."},
    privacy:
      {"Privacy",
       "Temporary inboxes expire automatically. Permanent mailbox data is stored only for signed-in users."},
    terms:
      {"Terms",
       "Use this service responsibly and do not use generated addresses for abuse, spam, or unlawful activity."}
  }

  @impl true
  def mount(params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    {title, body} = Map.fetch!(@copy, socket.assigns.live_action)

    {:ok,
     socket
     |> assign(:page_title, title)
     |> assign(:body, body)
     |> assign(:locale, locale)}
  end
end
