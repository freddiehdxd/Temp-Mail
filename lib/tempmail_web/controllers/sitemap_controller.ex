defmodule TempmailWeb.SitemapController do
  use TempmailWeb, :controller

  import Ecto.Query, warn: false

  @base_url "https://tempmailcentral.com"
  @locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
  @default_locale "en"

  def index(conn, _params) do
    entries = home_entries() ++ blog_listing_entries() ++ blog_post_entries() ++ static_entries()
    conn |> put_resp_content_type("application/xml") |> send_resp(200, render_sitemap(entries))
  end

  defp home_entries do
    now = Date.utc_today() |> Date.to_iso8601()
    Enum.map(@locales, fn locale ->
      %{url: locale_url(locale, ""), lastmod: now, changefreq: "daily", priority: "1.0",
        alternates: Enum.map(@locales, fn l -> {l, locale_url(l, "")} end)}
    end)
  end

  defp blog_listing_entries do
    now = Date.utc_today() |> Date.to_iso8601()
    Enum.map(@locales, fn locale ->
      %{url: locale_url(locale, "/blog"), lastmod: now, changefreq: "daily", priority: "0.9",
        alternates: Enum.map(@locales, fn l -> {l, locale_url(l, "/blog")} end)}
    end)
  end

  defp blog_post_entries do
    posts =
      Tempmail.Content.BlogPost
      |> where([p], p.status == "PUBLISHED")
      |> preload(:translations)
      |> Tempmail.Repo.all()

    Enum.flat_map(posts, fn post ->
      post_locales = Enum.map(post.translations, & &1.locale)
      Enum.map(post_locales, fn locale ->
        %{url: locale_url(locale, "/blog/#{post.slug}"),
          lastmod: (post.updated_at || post.inserted_at) |> DateTime.to_date() |> Date.to_iso8601(),
          changefreq: "weekly", priority: "0.8",
          alternates: Enum.map(post_locales, fn l -> {l, locale_url(l, "/blog/#{post.slug}")} end)}
      end)
    end)
  end

  defp static_entries do
    now = Date.utc_today() |> Date.to_iso8601()
    Enum.flat_map(~w(about privacy terms), fn page ->
      Enum.map(@locales, fn locale ->
        %{url: locale_url(locale, "/#{page}"), lastmod: now, changefreq: "monthly", priority: "0.5",
          alternates: Enum.map(@locales, fn l -> {l, locale_url(l, "/#{page}")} end)}
      end)
    end)
  end

  defp locale_url(@default_locale, path), do: "#{@base_url}#{path}"
  defp locale_url(locale, path), do: "#{@base_url}/#{locale}#{path}"

  defp render_sitemap(entries) do
    urls = Enum.map_join(entries, "\n", fn entry ->
      alternates = Enum.map_join(entry.alternates || [], "\n    ", fn {lang, href} ->
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
