defmodule TempmailWeb.BlogLive do
  use TempmailWeb, :live_view

  alias Tempmail.Content

  @base_url "https://tempmailcentral.com"

  @impl true
  def mount(params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    {:ok,
     socket
     |> assign(:page_title, "Blog - Guides on Temporary Email & Inbox Privacy")
     |> assign(:locale, locale)
     |> assign(:html_lang, locale)
     |> assign(:posts, Content.list_published_posts(locale))
     |> assign(
       :meta_description,
       "Practical guides from the TempMail Central team: when disposable email helps, when it hurts, how our deletion architecture works, and how to keep your real inbox clean."
     )
     |> assign(:og_title, "TempMail Central Blog")
     |> assign(
       :og_description,
       "Practical guides on disposable email, inbox privacy, and how TempMail Central works under the hood."
     )
     # Articles are English-first, so the listing canonicalizes to the
     # English URL from every locale variant.
     |> assign(:og_url, "#{@base_url}/blog")
     |> assign(:canonical_url, "#{@base_url}/blog")}
  end

  def post_translation(post, locale) do
    Enum.find(post.translations, &(&1.locale == locale)) ||
      Enum.find(post.translations, &(&1.locale == "en"))
  end
end
