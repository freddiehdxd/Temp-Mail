defmodule TempmailWeb.Api.BlogController do
  use TempmailWeb, :controller

  alias Tempmail.Content

  def index(conn, params) do
    locale = params["locale"] || "en"
    posts = Content.list_published_posts(locale)
    json(conn, %{
      success: true,
      posts: Enum.map(posts, fn post ->
        translation = List.first(post.translations)
        %{id: post.id, slug: post.slug, featured_image: post.featured_image,
          published_at: post.published_at, view_count: post.view_count,
          title: translation && translation.title, excerpt: translation && translation.excerpt}
      end)
    })
  end

  def show(conn, %{"slug" => slug} = params) do
    locale = params["locale"] || "en"
    case Content.get_published_post_by_slug(slug, locale) do
      nil -> conn |> put_status(:not_found) |> json(%{success: false, error: "Post not found"})
      post ->
        translation = List.first(post.translations)
        json(conn, %{
          success: true,
          post: %{id: post.id, slug: post.slug, featured_image: post.featured_image,
            published_at: post.published_at, view_count: post.view_count,
            title: translation && translation.title, excerpt: translation && translation.excerpt,
            content: translation && translation.content, meta_title: translation && translation.meta_title,
            meta_description: translation && translation.meta_description,
            categories: Enum.map(post.categories, &%{slug: &1.slug})}
        })
    end
  end
end
