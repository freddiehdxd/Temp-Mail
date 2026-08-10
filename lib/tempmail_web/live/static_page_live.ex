defmodule TempmailWeb.StaticPageLive do
  use TempmailWeb, :live_view

  @base_url "https://tempmailcentral.com"

  # These pages are maintained in English. Locale-prefixed routes render the
  # same content and canonicalize to the English URL, so search engines index
  # a single authoritative version instead of 20 thin duplicates.
  @meta %{
    about:
      {"About TempMail Central",
       "Who runs TempMail Central, why it exists, how disposable inboxes actually work under the hood, and how to reach the team that operates the service."},
    privacy:
      {"Privacy Policy",
       "What TempMail Central collects and what it never keeps: temporary inbox retention, account data, cookies, Google AdSense advertising, and how to delete your data."},
    terms:
      {"Terms of Service",
       "The rules for using TempMail Central: acceptable use, prohibited activity, account rules, service limitations, termination, and how to contact us."}
  }

  @impl true
  def mount(params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    action = socket.assigns.live_action
    {title, description} = Map.fetch!(@meta, action)

    {:ok,
     socket
     |> assign(:page_title, title)
     |> assign(:meta_description, description)
     |> assign(:canonical_url, "#{@base_url}/#{action}")
     |> assign(:html_lang, "en")
     |> assign(:locale, locale)}
  end
end
