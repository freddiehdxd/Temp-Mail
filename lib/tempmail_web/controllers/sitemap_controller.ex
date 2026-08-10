defmodule TempmailWeb.SitemapController do
  use TempmailWeb, :controller

  import Ecto.Query, warn: false

  @base_url "https://tempmailcentral.com"
  @locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
  @default_locale "en"

  # Only canonical, indexable pages belong here. The localized home pages are
  # fully translated, so each locale variant is listed with hreflang
  # alternates. Legal/about/contact pages and the blog listing are served in
  # English and canonicalize to the English URL, so only that URL is listed.
  # Blog posts are listed per locale that actually has a translation.
  def index(conn, _params) do
    entries = home_entries() ++ static_entries() ++ blog_listing_entries() ++ blog_post_entries()
    conn |> put_resp_content_type("application/xml") |> send_resp(200, render_sitemap(entries))
  end

  defp home_entries do
    now = Date.utc_today() |> Date.to_iso8601()

    alternates =
      [{"x-default", locale_url(@default_locale, "")}] ++
        Enum.map(@locales, fn l -> {l, locale_url(l, "")} end)

    Enum.map(@locales, fn locale ->
      %{
        url: locale_url(locale, ""),
        lastmod: now,
        changefreq: "daily",
        priority: "1.0",
        alternates: alternates
      }
    end)
  end

  defp blog_listing_entries do
    now = Date.utc_today() |> Date.to_iso8601()

    [
      %{
        url: locale_url(@default_locale, "/blog"),
        lastmod: now,
        changefreq: "weekly",
        priority: "0.8",
        alternates: []
      }
    ]
  end

  defp blog_post_entries do
    posts =
      Tempmail.Content.BlogPost
      |> where([p], p.status == "PUBLISHED")
      |> preload(:translations)
      |> Tempmail.Repo.all()

    Enum.flat_map(posts, fn post ->
      post_locales = Enum.map(post.translations, & &1.locale)

      alternates =
        if length(post_locales) > 1 do
          defaults =
            if @default_locale in post_locales,
              do: [{"x-default", locale_url(@default_locale, "/blog/#{post.slug}")}],
              else: []

          defaults ++ Enum.map(post_locales, fn l -> {l, locale_url(l, "/blog/#{post.slug}")} end)
        else
          []
        end

      Enum.map(post_locales, fn locale ->
        %{
          url: locale_url(locale, "/blog/#{post.slug}"),
          lastmod:
            (post.updated_at || post.inserted_at) |> DateTime.to_date() |> Date.to_iso8601(),
          changefreq: "monthly",
          priority: "0.7",
          alternates: alternates
        }
      end)
    end)
  end

  defp static_entries do
    now = Date.utc_today() |> Date.to_iso8601()

    Enum.map(~w(about contact privacy terms), fn page ->
      %{
        url: locale_url(@default_locale, "/#{page}"),
        lastmod: now,
        changefreq: "monthly",
        priority: "0.5",
        alternates: []
      }
    end)
  end

  defp locale_url(@default_locale, ""), do: "#{@base_url}/"
  defp locale_url(@default_locale, path), do: "#{@base_url}#{path}"
  defp locale_url(locale, path), do: "#{@base_url}/#{locale}#{path}"

  defp render_sitemap(entries) do
    urls =
      Enum.map_join(entries, "\n", fn entry ->
        alternates =
          Enum.map_join(entry.alternates || [], "\n    ", fn {lang, href} ->
            ~s(<xhtml:link rel="alternate" hreflang="#{lang}" href="#{href}"/>)
          end)

        """
          <url>
            <loc>#{entry.url}</loc>
            <lastmod>#{entry.lastmod}</lastmod>
            <changefreq>#{entry.changefreq}</changefreq>
            <priority>#{entry.priority}</priority>
            #{alternates}
          </url>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
            xmlns:xhtml="http://www.w3.org/1999/xhtml">
    #{urls}
    </urlset>
    """
  end
end
