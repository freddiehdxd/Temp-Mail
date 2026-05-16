defmodule TempmailWeb.AdminBlogEditorLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Content}

  @locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
  @locale_names %{
    "en" => "English", "es" => "Spanish", "fr" => "French", "de" => "German",
    "pt" => "Portuguese", "zh" => "Chinese", "ja" => "Japanese", "ar" => "Arabic",
    "ru" => "Russian", "hi" => "Hindi", "ko" => "Korean", "it" => "Italian",
    "nl" => "Dutch", "tr" => "Turkish", "pl" => "Polish", "vi" => "Vietnamese",
    "th" => "Thai", "id" => "Indonesian", "sv" => "Swedish", "el" => "Greek"
  }

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
    if socket.assigns.post, do: Content.delete_post(socket.assigns.post)
    {:noreply, push_navigate(socket, to: admin_path(socket.assigns.locale, "/admin/blog"))}
  end

  def handle_event("switch_locale", %{"locale" => loc}, socket) do
    {:noreply, assign(socket, :active_locale, loc)}
  end

  def handle_event("add_locale", %{"locale" => loc}, socket) do
    translations =
      Map.put_new(socket.assigns.translations, loc, %{
        "title" => "", "excerpt" => "", "content" => "",
        "meta_title" => "", "meta_description" => ""
      })

    {:noreply, socket |> assign(:translations, translations) |> assign(:active_locale, loc)}
  end

  def handle_event("remove_locale", %{"locale" => loc}, socket) do
    if map_size(socket.assigns.translations) <= 1 do
      {:noreply, socket}
    else
      translations = Map.delete(socket.assigns.translations, loc)
      active = if socket.assigns.active_locale == loc, do: Map.keys(translations) |> List.first(), else: socket.assigns.active_locale
      {:noreply, socket |> assign(:translations, translations) |> assign(:active_locale, active)}
    end
  end

  def handle_event("translate_all", _params, socket) do
    source_locale = socket.assigns.active_locale
    source = Map.get(socket.assigns.translations, source_locale, %{})

    if (source["title"] || "") == "" do
      {:noreply, assign(socket, :error, "Add a title before translating")}
    else
      api_key = Application.get_env(:tempmail, :deepl_api_key, "")

      if api_key == "" do
        {:noreply, assign(socket, :error, "DeepL API key not configured")}
      else
        target_locales = @locales -- [source_locale]
        fields = ["title", "excerpt", "content", "meta_title", "meta_description"]
        translations = socket.assigns.translations

        translations =
          Enum.reduce(target_locales, translations, fn loc, acc ->
            translated =
              Enum.reduce(fields, %{}, fn field, field_acc ->
                text = source[field] || ""

                if text == "" do
                  Map.put(field_acc, field, "")
                else
                  case translate_text(api_key, text, source_locale, loc) do
                    {:ok, result} -> Map.put(field_acc, field, result)
                    _ -> Map.put(field_acc, field, text)
                  end
                end
              end)

            Map.put(acc, loc, translated)
          end)

        {:noreply,
         socket
         |> assign(:translations, translations)
         |> assign(:error, nil)}
      end
    end
  end

  defp translate_text(api_key, text, _source, target) do
    target_lang = map_deepl_lang(target)
    url = "https://api-free.deepl.com/v2/translate"
    body = Jason.encode!(%{text: [text], target_lang: target_lang})
    headers = [{"Authorization", "DeepL-Auth-Key #{api_key}"}, {"Content-Type", "application/json"}]

    case Req.post(url, body: body, headers: headers) do
      {:ok, %{status: 200, body: %{"translations" => [%{"text" => translated} | _]}}} ->
        {:ok, translated}

      _ ->
        {:error, :translation_failed}
    end
  end

  defp map_deepl_lang("pt"), do: "PT-BR"
  defp map_deepl_lang("en"), do: "EN-US"
  defp map_deepl_lang("zh"), do: "ZH-HANS"
  defp map_deepl_lang(lang), do: String.upcase(lang)

  def locale_names, do: @locale_names
  def all_locales, do: @locales

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
        |> assign(:categories, Content.list_categories())
        |> assign(:error, nil)

      :edit ->
        post = Content.get_post!(params["id"])

        socket
        |> assign(:page_title, "Edit Post")
        |> assign(:locale, locale)
        |> assign(:post, post)
        |> assign(:form, to_form(post_form(post)))
        |> assign(:translations, post_translations(post))
        |> assign(:active_locale, post.translations |> List.first() |> then(&((&1 && &1.locale) || "en")))
        |> assign(:categories, Content.list_categories())
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

  defp default_form, do: %{"slug" => "", "status" => "DRAFT", "featured_image" => ""}

  defp post_form(post) do
    %{"slug" => post.slug, "status" => post.status, "featured_image" => post.featured_image || ""}
  end

  defp default_translations do
    %{"en" => %{"title" => "", "excerpt" => "", "content" => "", "meta_title" => "", "meta_description" => ""}}
  end

  defp post_translations(post) do
    post.translations
    |> Map.new(fn t ->
      {t.locale, %{"title" => t.title || "", "excerpt" => t.excerpt || "", "content" => t.content || "", "meta_title" => t.meta_title || "", "meta_description" => t.meta_description || ""}}
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
