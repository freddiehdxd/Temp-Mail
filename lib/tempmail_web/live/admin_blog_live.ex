defmodule TempmailWeb.AdminBlogLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Content}

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:page_title, "Blog")
       |> assign(:locale, Map.get(params, "locale", "en"))
       |> assign(:posts, Content.list_posts())
       |> assign(:categories, Content.list_categories())
       |> assign(:search, "")
       |> assign(:status_filter, "all")
       |> assign(:category_form, to_form(%{"slug" => "", "sort_order" => "0"}))
       |> assign(:error, nil)}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, assign(socket, :search, q)}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply, assign(socket, :status_filter, status)}
  end

  def handle_event("delete_post", %{"id" => id}, socket) do
    post = Content.get_post!(id)
    Content.delete_post(post)
    {:noreply, assign(socket, :posts, Content.list_posts())}
  end

  def handle_event("create_category", params, socket) do
    case Content.create_category(params) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:categories, Content.list_categories())
         |> assign(:category_form, to_form(%{"slug" => "", "sort_order" => "0"}))}

      {:error, changeset} ->
        {:noreply, assign(socket, :error, "Could not create category: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("delete_category", %{"id" => id}, socket) do
    category = Tempmail.Repo.get!(Tempmail.Content.BlogCategory, id)
    Content.delete_category(category)
    {:noreply, assign(socket, :categories, Content.list_categories())}
  end

  def filtered_posts(posts, search, status_filter) do
    posts
    |> Enum.filter(fn post ->
      status_match = status_filter == "all" || post.status == status_filter

      search_match =
        search == "" ||
          String.contains?(String.downcase(post.slug), String.downcase(search)) ||
          Enum.any?(post.translations, fn t ->
            String.contains?(String.downcase(t.title || ""), String.downcase(search))
          end)

      status_match && search_match
    end)
  end

  def post_title(post) do
    case post.translations do
      [t | _] -> t.title || post.slug
      _ -> post.slug
    end
  end
end
