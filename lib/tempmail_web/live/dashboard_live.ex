defmodule TempmailWeb.DashboardLive do
  use TempmailWeb, :live_view

  alias Tempmail.Mail

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    mailboxes = Mail.list_user_mailboxes(user)
    emails = Mail.list_user_emails(user, 5)
    total_emails = Enum.reduce(mailboxes, 0, &(length(&1.emails) + &2))

    unread_emails =
      Enum.reduce(mailboxes, 0, &(Enum.count(&1.emails, fn email -> !email.read end) + &2))

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:locale, Map.get(params, "locale", "en"))
     |> assign(:mailboxes, mailboxes)
     |> assign(:emails, emails)
     |> assign(:total_emails, total_emails)
     |> assign(:unread_emails, unread_emails)
     |> assign(:domains, Mail.list_user_domains(user))}
  end
end
