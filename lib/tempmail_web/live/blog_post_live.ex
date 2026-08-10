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
        # Prefer the requested locale; fall back to English so locale URLs
        # never render an empty article.
        translation =
          Enum.find(post.translations, &(&1.locale == locale)) ||
            Enum.find(post.translations, &(&1.locale == "en"))

        localized? = translation && translation.locale == locale

        title = (translation && translation.title) || post.slug
        excerpt = translation && translation.excerpt
        meta_title = (translation && translation.meta_title) || title
        meta_desc = (translation && translation.meta_description) || excerpt || ""

        # Untranslated locale variants canonicalize to the English article.
        canonical =
          if locale == "en" or not localized?,
            do: "#{@base_url}/blog/#{slug}",
            else: "#{@base_url}/#{locale}/blog/#{slug}"

        post_locales =
          post
          |> Tempmail.Repo.preload(:translations)
          |> Map.get(:translations, [])
          |> Enum.map(& &1.locale)

        hreflang =
          if length(post_locales) > 1 do
            defaults =
              if "en" in post_locales,
                do: [{"x-default", "#{@base_url}/blog/#{slug}"}],
                else: []

            defaults ++
              Enum.map(post_locales, fn
                "en" -> {"en", "#{@base_url}/blog/#{slug}"}
                loc -> {loc, "#{@base_url}/#{loc}/blog/#{slug}"}
              end)
          else
            nil
          end

        published_time =
          if post.published_at,
            do: DateTime.to_iso8601(post.published_at),
            else: nil

        {:ok,
         socket
         |> assign(:page_title, meta_title)
         |> assign(:locale, locale)
         |> assign(:html_lang, (localized? && locale) || "en")
         |> assign(:post, post)
         |> assign(:translation, translation)
         |> assign(:reading_minutes, reading_minutes(translation))
         |> assign(:meta_description, meta_desc)
         |> assign(:og_title, title)
         |> assign(:og_description, excerpt || meta_desc)
         |> assign(:og_type, "article")
         |> assign(:og_url, canonical)
         |> assign(:og_published_time, published_time)
         |> assign(:canonical_url, canonical)
         |> assign(:hreflang, hreflang)}
    end
  end

  defp reading_minutes(nil), do: 1

  defp reading_minutes(translation) do
    words =
      translation.content
      |> String.replace(~r/<[^>]*>/, " ")
      |> String.split()
      |> length()

    max(1, div(words + 199, 200))
  end
end
