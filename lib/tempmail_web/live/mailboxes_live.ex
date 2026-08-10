defmodule TempmailWeb.MailboxesLive do
  use TempmailWeb, :live_view

  alias Tempmail.Mail

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    mailboxes = Mail.list_user_mailboxes(user)
    selected = selected_mailbox(user, params, mailboxes)
    domains = Mail.list_available_mailbox_domains(user)

    if connected?(socket) do
      Enum.each(mailboxes, fn mb ->
        Phoenix.PubSub.subscribe(Tempmail.PubSub, Mail.inbox_topic(mb.address))
      end)
    end

    {:ok,
     socket
     |> assign(:page_title, "Mailboxes")
     |> assign(:locale, Map.get(params, "locale", "en"))
     |> assign(:mailboxes, mailboxes)
     |> assign(:selected_mailbox, selected)
     |> assign(:selected_email, nil)
     |> assign(:show_new, Map.get(params, "new") == "true")
     |> assign(:domains, domains)
     |> assign(
       :form,
       to_form(%{"prefix" => "", "domain" => default_domain(domains), "name" => ""})
     )
     |> assign(:error, nil)}
  end

  @impl true
  def handle_info({:persistent_email, _email}, socket) do
    {:noreply, refresh_selected(socket)}
  end

  def handle_info({:inbox_email, _message}, socket) do
    {:noreply, refresh_selected(socket)}
  end

  @impl true
  def handle_event("create", params, socket) do
    default_domain = default_domain(socket.assigns.domains)

    case Mail.create_user_mailbox(socket.assigns.current_user, %{
           "prefix" => Map.get(params, "prefix", ""),
           "domain" => Map.get(params, "domain", default_domain),
           "name" => Map.get(params, "name", "")
         }) do
      {:ok, mailbox} ->
        Phoenix.PubSub.subscribe(Tempmail.PubSub, Mail.inbox_topic(mailbox.address))
        mailboxes = Mail.list_user_mailboxes(socket.assigns.current_user)
        domains = Mail.list_available_mailbox_domains(socket.assigns.current_user)

        {:noreply,
         socket
         |> assign(:mailboxes, mailboxes)
         |> assign(:domains, domains)
         |> assign(:selected_mailbox, Enum.find(mailboxes, &(&1.id == mailbox.id)))
         |> assign(:show_new, false)
         |> assign(
           :form,
           to_form(%{"prefix" => "", "domain" => default_domain(domains), "name" => ""})
         )
         |> assign(:error, nil)}

      {:error, reason} ->
        {:noreply, assign(socket, :error, mailbox_error(reason))}
    end
  end

  def handle_event("show_new", _params, socket), do: {:noreply, assign(socket, :show_new, true)}
  def handle_event("hide_new", _params, socket), do: {:noreply, assign(socket, :show_new, false)}

  def handle_event("select_mailbox", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_mailbox, Mail.get_user_mailbox(socket.assigns.current_user, id))
     |> assign(:selected_email, nil)}
  end

  def handle_event("select_email", %{"id" => id}, socket) do
    email = Enum.find(socket.assigns.selected_mailbox.emails, &(&1.id == id))

    if email && !email.read do
      Mail.update_user_email(socket.assigns.current_user, id, %{read: true})
    end

    selected_mailbox =
      if socket.assigns.selected_mailbox do
        Mail.get_user_mailbox(socket.assigns.current_user, socket.assigns.selected_mailbox.id)
      end

    {:noreply,
     socket
     |> assign(:selected_mailbox, selected_mailbox)
     |> assign(:selected_email, email && %{email | read: true})}
  end

  def handle_event("back_to_list", _params, socket),
    do: {:noreply, assign(socket, :selected_email, nil)}

  def handle_event("toggle_star", %{"id" => id}, socket) do
    email = selected_email(socket, id)

    if email,
      do: Mail.update_user_email(socket.assigns.current_user, id, %{starred: !email.starred})

    {:noreply, refresh_selected(socket)}
  end

  def handle_event("delete_email", %{"id" => id}, socket) do
    Mail.delete_user_email(socket.assigns.current_user, id)
    {:noreply, refresh_selected(assign(socket, :selected_email, nil))}
  end

  def handle_event("delete_mailbox", %{"id" => id}, socket) do
    Mail.delete_user_mailbox(socket.assigns.current_user, id)

    {:noreply,
     socket
     |> assign(:mailboxes, Mail.list_user_mailboxes(socket.assigns.current_user))
     |> assign(:selected_mailbox, nil)}
  end

  defp selected_mailbox(user, params, mailboxes) do
    case Map.get(params, "mailbox") do
      nil -> List.first(mailboxes)
      id -> Mail.get_user_mailbox(user, id) || List.first(mailboxes)
    end
  end

  defp selected_email(socket, id) do
    cond do
      socket.assigns.selected_email && socket.assigns.selected_email.id == id ->
        socket.assigns.selected_email

      socket.assigns.selected_mailbox ->
        Enum.find(socket.assigns.selected_mailbox.emails, &(&1.id == id))

      true ->
        nil
    end
  end

  defp refresh_selected(socket) do
    mailboxes = Mail.list_user_mailboxes(socket.assigns.current_user)

    selected_mailbox =
      if socket.assigns.selected_mailbox do
        Mail.get_user_mailbox(socket.assigns.current_user, socket.assigns.selected_mailbox.id)
      end

    selected_email =
      if socket.assigns.selected_email && selected_mailbox do
        Enum.find(selected_mailbox.emails, &(&1.id == socket.assigns.selected_email.id))
      end

    socket
    |> assign(:mailboxes, mailboxes)
    |> assign(:selected_mailbox, selected_mailbox)
    |> assign(:selected_email, selected_email)
  end

  defp default_domain(domains) do
    case domains do
      [] -> Application.get_env(:tempmail, :default_domain, "tempmail.com")
      domains -> (Enum.find(domains, & &1.is_default) || hd(domains)).domain
    end
  end

  defp mailbox_error(:domain_not_verified),
    do: "Verify this custom domain before creating mailboxes on it."

  defp mailbox_error(:domain_not_allowed),
    do: "This domain is not available for your account."

  defp mailbox_error(:reserved_prefix),
    do: "That prefix is reserved for service addresses. Please pick another one."

  defp mailbox_error(%Ecto.Changeset{} = changeset),
    do: "Could not create mailbox: #{inspect(changeset.errors)}"

  defp mailbox_error(reason), do: "Could not create mailbox: #{inspect(reason)}"
end
