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
       |> assign(:post_form, to_form(%{"slug" => "", "status" => "DRAFT"}))
       |> assign(:category_form, to_form(%{"slug" => "", "sort_order" => "0"}))
       |> assign(:error, nil)}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("create_post", params, socket) do
    attrs = Map.put(params, "author_id", socket.assigns.current_user.id)

    case Content.create_post(attrs) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> assign(:posts, Content.list_posts())
         |> assign(:post_form, to_form(%{"slug" => "", "status" => "DRAFT"}))
         |> assign(:error, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :error, "Could not create post: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("create_category", params, socket) do
    case Content.create_category(params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> assign(:categories, Content.list_categories())
         |> assign(:category_form, to_form(%{"slug" => "", "sort_order" => "0"}))
         |> assign(:error, nil)}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :error, "Could not create category: #{inspect(changeset.errors)}")}
    end
  end
end
