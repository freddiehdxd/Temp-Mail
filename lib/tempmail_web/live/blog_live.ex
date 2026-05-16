defmodule TempmailWeb.BlogLive do
  use TempmailWeb, :live_view

  alias Tempmail.Content

  @base_url "https://tempmailcentral.com"
  @locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)

  @impl true
  def mount(params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    canonical = if locale == "en", do: "#{@base_url}/blog", else: "#{@base_url}/#{locale}/blog"

    {:ok,
     socket
     |> assign(:page_title, TempmailWeb.I18n.t(locale, "blog.pageTitle", "Blog - Tips & Privacy Guides"))
     |> assign(:locale, locale)
     |> assign(:html_lang, locale)
     |> assign(:posts, Content.list_published_posts(locale))
     |> assign(:meta_description, TempmailWeb.I18n.t(locale, "blog.metaDescription", "Learn about temporary email, online privacy, spam protection, and how to stay safe online with our expert guides and tips."))
     |> assign(:og_title, TempmailWeb.I18n.t(locale, "blog.pageTitle", "Blog - Temp Mail Tips & Privacy Guides"))
     |> assign(:og_description, TempmailWeb.I18n.t(locale, "blog.metaDescription", "Expert guides on temporary email and online privacy."))
     |> assign(:og_image, "#{@base_url}/og-image.png")
     |> assign(:og_url, canonical)
     |> assign(:canonical_url, canonical)
     |> assign(:hreflang, Enum.map(@locales, fn
       "en" -> {"en", "#{@base_url}/blog"}
       loc -> {loc, "#{@base_url}/#{loc}/blog"}
     end))}
  end
end
