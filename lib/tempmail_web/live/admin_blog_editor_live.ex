defmodule TempmailWeb.AdminBlogEditorLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Content}

  @locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      {:ok, mount_editor(socket, params)}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    attrs = editor_attrs(socket, params)

    result =
      if socket.assigns.post do
        Content.update_post_with_translations(socket.assigns.post, attrs)
      else
        Content.upsert_post(attrs)
      end

    case result do
      {:ok, _post} ->
        {:noreply, push_navigate(socket, to: admin_path(socket.assigns.locale, "/admin/blog"))}

      {:error, reason} ->
        {:noreply, assign(socket, :error, inspect(reason))}
    end
  rescue
    error ->
      {:noreply, assign(socket, :error, Exception.message(error))}
  end

  def handle_event("delete", _params, socket) do
    if socket.assigns.post do
      Content.delete_post(socket.assigns.post)
    end

    {:noreply, push_navigate(socket, to: admin_path(socket.assigns.locale, "/admin/blog"))}
  end

  defp mount_editor(socket, params) do
    locale = Map.get(params, "locale", "en")

    case socket.assigns.live_action do
      :new ->
        socket
        |> assign(:page_title, "Create New Post")
        |> assign(:locale, locale)
        |> assign(:post, nil)
        |> assign(:form, to_form(default_form()))
        |> assign(:translations, default_translations())
        |> assign(:active_locale, "en")
        |> assign(:locales, @locales)
        |> assign(:error, nil)

      :edit ->
        post = Content.get_post!(params["id"])

        socket
        |> assign(:page_title, "Edit Post")
        |> assign(:locale, locale)
        |> assign(:post, post)
        |> assign(:form, to_form(post_form(post)))
        |> assign(:translations, post_translations(post))
        |> assign(
          :active_locale,
          post.translations |> List.first() |> then(&((&1 && &1.locale) || "en"))
        )
        |> assign(:locales, @locales)
        |> assign(:error, nil)
    end
  end

  defp editor_attrs(socket, params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %{
      "slug" => Map.get(params, "slug", ""),
      "status" => Map.get(params, "status", "DRAFT"),
      "featured_image" => blank_to_nil(Map.get(params, "featured_image")),
      "author_id" => socket.assigns.current_user.id,
      "published_at" => if(Map.get(params, "status") == "PUBLISHED", do: now),
      "translations" => Map.get(params, "translations", %{})
    }
  end

  defp default_form do
    %{"slug" => "", "status" => "DRAFT", "featured_image" => ""}
  end

  defp post_form(post) do
    %{
      "slug" => post.slug,
      "status" => post.status,
      "featured_image" => post.featured_image || ""
    }
  end

  defp default_translations do
    %{
      "en" => %{
        "title" => "",
        "excerpt" => "",
        "content" => "",
        "meta_title" => "",
        "meta_description" => ""
      }
    }
  end

  defp post_translations(post) do
    post.translations
    |> Map.new(fn translation ->
      {translation.locale,
       %{
         "title" => translation.title || "",
         "excerpt" => translation.excerpt || "",
         "content" => translation.content || "",
         "meta_title" => translation.meta_title || "",
         "meta_description" => translation.meta_description || ""
       }}
    end)
    |> case do
      empty when empty == %{} -> default_translations()
      translations -> translations
    end
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp admin_path("en", href), do: href
  defp admin_path(nil, href), do: href
  defp admin_path(locale, href), do: "/#{locale}#{href}"
end
