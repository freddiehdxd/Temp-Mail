defmodule TempmailWeb.DashboardEmailsLive do
  use TempmailWeb, :live_view

  alias Tempmail.Mail

  @impl true
  def mount(params, _session, socket) do
    page = socket.assigns.live_action

    emails =
      case page do
        :starred -> Mail.list_user_emails(socket.assigns.current_user, starred: true)
        :archived -> Mail.list_user_emails(socket.assigns.current_user, archived: true)
      end

    {:ok,
     socket
     |> assign(:page_title, title(page))
     |> assign(:locale, Map.get(params, "locale", "en"))
     |> assign(:active, page)
     |> assign(:title, title(page))
     |> assign(:subtitle, subtitle(page))
     |> assign(:emails, emails)}
  end

  @impl true
  def handle_event("toggle_star", %{"id" => id}, socket) do
    email = Enum.find(socket.assigns.emails, &(&1.id == id))

    if email,
      do: Mail.update_user_email(socket.assigns.current_user, id, %{starred: !email.starred})

    {:noreply, refresh(socket)}
  end

  def handle_event("toggle_archive", %{"id" => id}, socket) do
    email = Enum.find(socket.assigns.emails, &(&1.id == id))

    if email,
      do: Mail.update_user_email(socket.assigns.current_user, id, %{archived: !email.archived})

    {:noreply, refresh(socket)}
  end

  defp refresh(socket) do
    emails =
      case socket.assigns.active do
        :starred -> Mail.list_user_emails(socket.assigns.current_user, starred: true)
        :archived -> Mail.list_user_emails(socket.assigns.current_user, archived: true)
      end

    assign(socket, :emails, emails)
  end

  defp title(:starred), do: "Starred"
  defp title(:archived), do: "Archived"

  defp subtitle(:starred), do: "Important persistent emails you marked with a star."
  defp subtitle(:archived), do: "Messages moved out of your active mailbox views."
end
