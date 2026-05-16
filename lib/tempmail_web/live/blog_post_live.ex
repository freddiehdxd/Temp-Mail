defmodule TempmailWeb.BlogPostLive do
  use TempmailWeb, :live_view

  alias Tempmail.Content

  @impl true
  def mount(%{"slug" => slug} = params, _session, socket) do
    locale = Map.get(params, "locale", "en")

    case Content.get_published_post_by_slug(slug, locale) do
      nil ->
        {:ok, socket |> put_flash(:error, "Post not found") |> push_navigate(to: ~p"/blog")}

      post ->
        translation = List.first(post.translations)

        {:ok,
         socket
         |> assign(:page_title, (translation && translation.title) || post.slug)
         |> assign(:locale, locale)
         |> assign(:post, post)
         |> assign(:translation, translation)}
    end
  end
end
