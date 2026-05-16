defmodule TempmailWeb.AdminLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Mail}

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      users = Accounts.list_users()
      domains = Mail.list_domains()
      stats = Mail.recent_stats(14)
      sessions = Mail.list_recent_temp_email_sessions(5)
      total_generated = Enum.reduce(stats, 0, &(&1.generated + &2))
      total_received = Enum.reduce(stats, 0, &(&1.received + &2))

      {:ok,
       socket
       |> assign(:page_title, "Admin")
       |> assign(:locale, Map.get(params, "locale", "en"))
       |> assign(:users, users)
       |> assign(:domains, domains)
       |> assign(:stats, stats)
       |> assign(:sessions, sessions)
       |> assign(:total_generated, total_generated)
       |> assign(:total_received, total_received)
       |> assign(
         :new_users_count,
         Enum.count(users, &(Date.diff(Date.utc_today(), DateTime.to_date(&1.inserted_at)) <= 7))
       )
       |> assign(:settings, Mail.list_settings())}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
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
end
