defmodule TempmailWeb.BlogPostLive do
  use TempmailWeb, :live_view

  alias Tempmail.Content

  @base_url "https://tempmailcentral.com"

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    case Content.get_published_post_by_slug(slug, locale) do
      nil ->
        {:ok, socket |> put_flash(:error, "Post not found") |> push_navigate(to: ~p"/blog")}

      post ->
        translation = List.first(post.translations)
        title = (translation && translation.title) || post.slug
        excerpt = translation && translation.excerpt
        meta_title = (translation && translation.meta_title) || title
        meta_desc = (translation && translation.meta_description) || excerpt || ""
        canonical = if locale == "en", do: "#{@base_url}/blog/#{slug}", else: "#{@base_url}/#{locale}/blog/#{slug}"

        post_locales =
          post
          |> Tempmail.Repo.preload(:translations)
          |> Map.get(:translations, [])
          |> Enum.map(& &1.locale)

        hreflang =
          Enum.map(post_locales, fn
            "en" -> {"en", "#{@base_url}/blog/#{slug}"}
            loc -> {loc, "#{@base_url}/#{loc}/blog/#{slug}"}
          end)

        published_time =
          if post.published_at,
            do: DateTime.to_iso8601(post.published_at),
            else: nil

        {:ok,
         socket
         |> assign(:page_title, meta_title)
         |> assign(:locale, locale)
         |> assign(:html_lang, locale)
         |> assign(:post, post)
         |> assign(:translation, translation)
         |> assign(:meta_description, meta_desc)
         |> assign(:og_title, title)
         |> assign(:og_description, excerpt || meta_desc)
         |> assign(:og_type, "article")
         |> assign(:og_url, canonical)
         |> assign(:og_image, post.featured_image || "#{@base_url}/og-image.png")
         |> assign(:og_published_time, published_time)
         |> assign(:canonical_url, canonical)
         |> assign(:hreflang, hreflang)}
    end
  end
end
