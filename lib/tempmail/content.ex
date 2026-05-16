defmodule Tempmail.Content do
  @moduledoc """
  Blog content context for localized posts and categories.
  """

  import Ecto.Query, warn: false
  alias Tempmail.Repo
  alias Tempmail.Content.{BlogCategory, BlogPost}

  def list_published_posts(locale \\ "en") do
    BlogPost
    |> where([p], p.status == "PUBLISHED")
    |> order_by([p], desc: p.published_at)
    |> preload([
      :categories,
      translations: ^from(t in Tempmail.Content.BlogPostTranslation, where: t.locale == ^locale)
    ])
    |> Repo.all()
  end

  def get_published_post_by_slug(slug, locale \\ "en") do
    BlogPost
    |> where([p], p.slug == ^slug and p.status == "PUBLISHED")
    |> preload([
      :categories,
      translations: ^from(t in Tempmail.Content.BlogPostTranslation, where: t.locale == ^locale)
    ])
    |> Repo.one()
  end

  def list_posts do
    BlogPost |> order_by([p], desc: p.inserted_at) |> preload(:translations) |> Repo.all()
  end

  def get_post!(id), do: Repo.get!(BlogPost, id) |> Repo.preload(:translations)

  def create_post(attrs), do: %BlogPost{} |> BlogPost.changeset(attrs) |> Repo.insert()

  def update_post(%BlogPost{} = post, attrs),
    do: post |> BlogPost.changeset(attrs) |> Repo.update()

  def delete_post(%BlogPost{} = post), do: Repo.delete(post)

  def upsert_post(attrs) do
    attrs = normalize_post_attrs(attrs)

    Repo.transaction(fn ->
      post =
        %BlogPost{}
        |> BlogPost.changeset(Map.drop(attrs, ["translations"]))
        |> Repo.insert!()

      upsert_translations(post, Map.get(attrs, "translations", %{}))
      Repo.preload(post, :translations)
    end)
  end

  def update_post_with_translations(%BlogPost{} = post, attrs) do
    attrs = normalize_post_attrs(attrs)

    Repo.transaction(fn ->
      post =
        post
        |> BlogPost.changeset(Map.drop(attrs, ["translations"]))
        |> Repo.update!()

      upsert_translations(post, Map.get(attrs, "translations", %{}))
      Repo.preload(post, :translations, force: true)
    end)
  end

  def list_categories do
    BlogCategory |> order_by([c], asc: c.sort_order) |> preload(:translations) |> Repo.all()
  end

  def create_category(attrs),
    do: %BlogCategory{} |> BlogCategory.changeset(attrs) |> Repo.insert()

  def delete_category(%BlogCategory{} = category), do: Repo.delete(category)

  defp normalize_post_attrs(attrs) do
    attrs
    |> stringify_keys()
    |> Map.update("published_at", nil, fn
      "" -> nil
      value -> value
    end)
  end

  defp upsert_translations(post, translations) when is_map(translations) do
    translations
    |> Enum.reject(fn {_locale, attrs} ->
      String.trim(to_string(Map.get(attrs, "title", ""))) == ""
    end)
    |> Enum.each(fn {locale, attrs} ->
      attrs =
        attrs
        |> stringify_keys()
        |> Map.put("locale", locale)
        |> Map.put("post_id", post.id)

      case Repo.get_by(Tempmail.Content.BlogPostTranslation, post_id: post.id, locale: locale) do
        nil ->
          %Tempmail.Content.BlogPostTranslation{}
          |> Tempmail.Content.BlogPostTranslation.changeset(attrs)
          |> Repo.insert!()

        translation ->
          translation
          |> Tempmail.Content.BlogPostTranslation.changeset(attrs)
          |> Repo.update!()
      end
    end)
  end

  defp upsert_translations(_post, _translations), do: :ok

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end
end
