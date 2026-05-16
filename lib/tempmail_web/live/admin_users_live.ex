defmodule TempmailWeb.AdminUsersLive do
  use TempmailWeb, :live_view

  alias Tempmail.Accounts

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:page_title, "Users")
       |> assign(:locale, Map.get(params, "locale", "en"))
       |> assign(:search, "")
       |> assign(:users, Accounts.list_users())}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  def handle_event("ban", %{"id" => id}, socket) do
    socket.assigns.users
    |> Enum.find(&(&1.id == id))
    |> then(&(&1 && Accounts.ban_user(&1, "Banned by admin")))

    {:noreply, assign(socket, :users, Accounts.list_users())}
  end

  def handle_event("unban", %{"id" => id}, socket) do
    socket.assigns.users |> Enum.find(&(&1.id == id)) |> then(&(&1 && Accounts.unban_user(&1)))
    {:noreply, assign(socket, :users, Accounts.list_users())}
  end

  def handle_event("toggle_admin", %{"id" => id}, socket) do
    user = Enum.find(socket.assigns.users, &(&1.id == id))

    if user && socket.assigns.current_user.role == "SUPER_ADMIN" && user.role != "SUPER_ADMIN" do
      Accounts.update_user_role(user, if(user.role == "ADMIN", do: "USER", else: "ADMIN"))
    end

    {:noreply, assign(socket, :users, Accounts.list_users())}
  end

  def filtered_users(users, search) do
    query = String.downcase(search || "")

    Enum.filter(users, fn user ->
      query == "" or
        String.contains?(String.downcase(user.name || ""), query) or
        String.contains?(String.downcase(user.email || ""), query)
    end)
  end
end
