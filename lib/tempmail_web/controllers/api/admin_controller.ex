defmodule TempmailWeb.Api.AdminController do
  use TempmailWeb, :controller

  alias Tempmail.{Accounts, Mail, Content}

  plug :require_admin

  # --- Domains ---

  def domains(conn, _params), do: json(conn, %{success: true, domains: Mail.list_domains()})

  def create_domain(conn, params) do
    case Mail.create_domain(params, conn.assigns.current_user) do
      {:ok, domain} -> json(conn, %{success: true, domain: domain})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def update_domain(conn, %{"id" => id} = params) do
    domain = Mail.get_domain!(id)
    attrs = Map.take(params, ["is_active", "description"])
    case Mail.update_domain(domain, attrs) do
      {:ok, domain} -> json(conn, %{success: true, domain: domain})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_domain(conn, %{"id" => id}) do
    domain = Mail.get_domain!(id)
    case Mail.delete_domain(domain, conn.assigns.current_user) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def set_default_domain(conn, %{"id" => id}) do
    domain = Mail.get_domain!(id)
    case Mail.set_default_domain(domain) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Failed to set default"})
    end
  end

  # --- Users ---

  def users(conn, _params), do: json(conn, %{success: true, users: Accounts.list_users()})

  def ban_user(conn, %{"id" => id} = params) do
    user = Accounts.get_user!(id)
    admin = conn.assigns.current_user
    cond do
      user.id == admin.id ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Cannot ban yourself"})
      Accounts.super_admin?(user) ->
        conn |> put_status(:forbidden) |> json(%{success: false, error: "Cannot ban a super admin"})
      user.banned ->
        Accounts.unban_user(user, admin)
        json(conn, %{success: true, banned: false})
      true ->
        Accounts.ban_user(user, params["reason"], admin)
        json(conn, %{success: true, banned: true})
    end
  end

  def update_role(conn, %{"id" => id, "role" => role}) do
    user = Accounts.get_user!(id)
    admin = conn.assigns.current_user
    cond do
      user.id == admin.id ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Cannot change your own role"})
      not Accounts.super_admin?(admin) ->
        conn |> put_status(:forbidden) |> json(%{success: false, error: "Only super admins can change roles"})
      role == "SUPER_ADMIN" ->
        conn |> put_status(:forbidden) |> json(%{success: false, error: "Cannot assign super admin role"})
      true ->
        case Accounts.update_user_role(user, role, admin) do
          {:ok, _} -> json(conn, %{success: true, role: role})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Invalid role"})
        end
    end
  end

  # --- Settings ---

  def get_settings(conn, _params) do
    settings = Mail.list_settings() |> Enum.map(fn s -> %{key: s.key, value: s.value, type: s.type} end)
    json(conn, %{success: true, settings: settings})
  end

  def update_settings(conn, %{"settings" => settings}) when is_list(settings) do
    Enum.each(settings, fn %{"key" => key, "value" => value} = s ->
      Mail.upsert_setting(key, value, Map.get(s, "type", "string"))
    end)
    Mail.create_audit_log(conn.assigns.current_user, "settings.update", nil, inspect(settings))
    json(conn, %{success: true})
  end

  def update_settings(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{success: false, error: "Expected settings array"})
  end

  def test_mailcow(conn, _params) do
    case Tempmail.Integrations.Mailcow.test_connection() do
      {:ok, _} -> json(conn, %{success: true, connected: true})
      {:error, reason} -> json(conn, %{success: true, connected: false, error: reason})
    end
  end

  # --- Analytics ---

  def analytics(conn, params) do
    days = params |> Map.get("days", "14") |> String.to_integer()
    json(conn, %{success: true, stats: Mail.recent_stats(days)})
  end

  # --- Blog Posts ---

  def list_posts(conn, _params) do
    posts = Content.list_posts()
    json(conn, %{success: true, posts: Enum.map(posts, &serialize_post/1)})
  end

  def get_post(conn, %{"id" => id}) do
    post = Content.get_post!(id)
    json(conn, %{success: true, post: serialize_post(post)})
  end

  def create_post(conn, params) do
    attrs = Map.put(params, "author_id", conn.assigns.current_user.id)
    case Content.upsert_post(attrs) do
      {:ok, post} ->
        Mail.create_audit_log(conn.assigns.current_user, "blog.create", post.slug)
        conn |> put_status(:created) |> json(%{success: true, post: serialize_post(post)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def update_post(conn, %{"id" => id} = params) do
    post = Content.get_post!(id)
    case Content.update_post_with_translations(post, params) do
      {:ok, post} ->
        Mail.create_audit_log(conn.assigns.current_user, "blog.update", post.slug)
        json(conn, %{success: true, post: serialize_post(post)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_post(conn, %{"id" => id}) do
    post = Content.get_post!(id)
    case Content.delete_post(post) do
      {:ok, _} ->
        Mail.create_audit_log(conn.assigns.current_user, "blog.delete", post.slug)
        json(conn, %{success: true})
      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Delete failed"})
    end
  end

  # --- Blog Categories ---

  def list_categories(conn, _params) do
    categories = Content.list_categories()
    json(conn, %{success: true, categories: Enum.map(categories, &serialize_category/1)})
  end

  def create_category(conn, params) do
    case Content.create_category(params) do
      {:ok, category} -> conn |> put_status(:created) |> json(%{success: true, category: serialize_category(category)})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_category(conn, %{"id" => id}) do
    category = Tempmail.Repo.get!(Tempmail.Content.BlogCategory, id)
    case Content.delete_category(category) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Delete failed"})
    end
  end

  # --- File Upload ---

  def upload(conn, %{"file" => %Plug.Upload{} = upload}) do
    allowed = ~w(.jpg .jpeg .png .gif .webp)
    ext = Path.extname(upload.filename) |> String.downcase()
    cond do
      ext not in allowed ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "File type not allowed"})
      true ->
        upload_dir = Path.join([:code.priv_dir(:tempmail), "static", "uploads"])
        File.mkdir_p!(upload_dir)
        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = Path.join(upload_dir, filename)
        File.cp!(upload.path, dest)
        json(conn, %{success: true, url: "/uploads/#{filename}"})
    end
  end

  def upload(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{success: false, error: "No file uploaded"})
  end

  # --- Translation (DeepL) ---

  def translate(conn, %{"text" => text, "source_lang" => source, "target_lang" => target}) do
    api_key = Application.get_env(:tempmail, :deepl_api_key, "")
    if api_key == "" do
      conn |> put_status(:service_unavailable) |> json(%{success: false, error: "DeepL API not configured"})
    else
      url = "https://api-free.deepl.com/v2/translate"
      body = Jason.encode!(%{text: [text], source_lang: String.upcase(source), target_lang: map_deepl_lang(target)})
      headers = [{"Authorization", "DeepL-Auth-Key #{api_key}"}, {"Content-Type", "application/json"}]
      case Req.post(url, body: body, headers: headers) do
        {:ok, %{status: 200, body: %{"translations" => [%{"text" => translated} | _]}}} ->
          json(conn, %{success: true, translated_text: translated})
        {:ok, resp} ->
          conn |> put_status(:bad_gateway) |> json(%{success: false, error: "DeepL returned #{resp.status}"})
        {:error, reason} ->
          conn |> put_status(:bad_gateway) |> json(%{success: false, error: inspect(reason)})
      end
    end
  end

  def translate(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{success: false, error: "Missing text, source_lang, or target_lang"})
  end

  # --- Helpers ---

  defp require_admin(conn, _opts) do
    if Accounts.admin?(conn.assigns[:current_user]) do
      conn
    else
      conn |> put_status(:forbidden) |> json(%{success: false, error: "Forbidden"}) |> halt()
    end
  end

  defp map_deepl_lang("pt"), do: "PT-BR"
  defp map_deepl_lang("en"), do: "EN-US"
  defp map_deepl_lang("zh"), do: "ZH-HANS"
  defp map_deepl_lang(lang), do: String.upcase(lang)

  defp serialize_post(post) do
    %{id: post.id, slug: post.slug, status: post.status, author_id: post.author_id,
      featured_image: post.featured_image, view_count: post.view_count, published_at: post.published_at,
      translations: Enum.map(post.translations || [], fn t ->
        %{locale: t.locale, title: t.title, excerpt: t.excerpt, content: t.content, meta_title: t.meta_title, meta_description: t.meta_description}
      end)}
  end

  defp serialize_category(cat) do
    %{id: cat.id, slug: cat.slug, is_active: cat.is_active, sort_order: cat.sort_order,
      translations: Enum.map(cat.translations || [], fn t ->
        %{locale: t.locale, name: t.name, description: t.description}
      end)}
  end
end
