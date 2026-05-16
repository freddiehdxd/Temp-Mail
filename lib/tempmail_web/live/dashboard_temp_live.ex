defmodule TempmailWeb.DashboardTempLive do
  use TempmailWeb, :live_view

  alias Tempmail.Mail

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Temp Emails")
      |> assign(:locale, Map.get(params, "locale", "en"))
      |> assign(:domains, Mail.list_active_domains())
      |> assign(:sessions, Mail.list_temp_email_sessions(socket.assigns.current_user))
      |> assign(:temp_email, nil)
      |> assign(:emails, [])
      |> assign(:selected_email, nil)
      |> assign(:ttl, 0)
      |> assign(:error, nil)

    socket =
      if connected?(socket) do
        generate_temp_email(socket)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("generate", params, socket) do
    {:noreply, generate_temp_email(socket, Map.get(params, "domain", ""))}
  end

  def handle_event("refresh", _params, socket) do
    with address when is_binary(address) <- temp_address(socket),
         {:ok, emails} <- Mail.get_inbox(address) do
      {:noreply, assign(socket, :emails, emails)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("extend", %{"duration" => duration}, socket) do
    with address when is_binary(address) <- temp_address(socket),
         {:ok, temp_email} <-
           Mail.extend_temp_email(address, duration, socket.assigns.current_user) do
      {:noreply,
       socket
       |> assign(:temp_email, temp_email)
       |> assign(:ttl, temp_email["ttl"] || temp_email[:ttl])
       |> assign(:sessions, Mail.list_temp_email_sessions(socket.assigns.current_user))}
    else
      _ -> {:noreply, assign(socket, :error, "Failed to extend this address.")}
    end
  end

  def handle_event("save", _params, socket) do
    with address when is_binary(address) <- temp_address(socket),
         {:ok, _mailbox} <- Mail.promote_temp_email(socket.assigns.current_user, address) do
      {:noreply,
       push_navigate(socket, to: dashboard_path(socket.assigns.locale, "/dashboard/mailboxes"))}
    else
      {:error, :reserved_prefix} ->
        {:noreply,
         assign(socket, :error, "That prefix is reserved and cannot be saved permanently.")}

      _ ->
        {:noreply, assign(socket, :error, "Failed to save this address as a mailbox.")}
    end
  end

  def handle_event("select", %{"id" => id}, socket) do
    email = Enum.find(socket.assigns.emails, &(&1["id"] == id))
    if email && temp_address(socket), do: Mail.mark_temp_email_read(temp_address(socket), id)
    {:noreply, assign(socket, :selected_email, email && Map.put(email, "read", true))}
  end

  def handle_event("back", _params, socket), do: {:noreply, assign(socket, :selected_email, nil)}

  def handle_event("delete", %{"id" => id}, socket) do
    address = temp_address(socket)
    if address, do: Mail.delete_temp_email(address, id)

    {:noreply,
     socket
     |> assign(:emails, Enum.reject(socket.assigns.emails, &(&1["id"] == id)))
     |> assign(:selected_email, nil)}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{ttl: ttl}} = socket) when ttl > 1 do
    Process.send_after(self(), :tick, 1_000)
    {:noreply, assign(socket, :ttl, ttl - 1)}
  end

  def handle_info(:tick, socket) do
    {:noreply,
     socket
     |> assign(:ttl, 0)
     |> assign(:temp_email, nil)
     |> assign(:emails, [])
     |> assign(:selected_email, nil)}
  end

  def handle_info({:inbox_email, message}, socket) do
    {:noreply, assign(socket, :emails, [message | socket.assigns.emails])}
  end

  def handle_info({:inbox_updated, messages}, socket) do
    {:noreply, assign(socket, :emails, messages)}
  end

  defp generate_temp_email(socket, domain \\ "") do
    case Mail.create_temp_email(%{"domain" => domain}) do
      {:ok, temp_email} ->
        address = temp_email[:address] || temp_email["address"]
        Mail.extend_temp_email(address, Mail.default_ttl(), socket.assigns.current_user)

        if connected?(socket),
          do: Phoenix.PubSub.subscribe(Tempmail.PubSub, Mail.inbox_topic(address))

        Process.send_after(self(), :tick, 1_000)

        socket
        |> assign(:temp_email, temp_email)
        |> assign(:emails, [])
        |> assign(:selected_email, nil)
        |> assign(:ttl, temp_email[:ttl] || temp_email["ttl"])
        |> assign(:sessions, Mail.list_temp_email_sessions(socket.assigns.current_user))
        |> assign(:error, nil)

      _ ->
        assign(
          socket,
          :error,
          "Failed to generate email address. Check Redis and domain configuration."
        )
    end
  end

  defp temp_address(%{assigns: %{temp_email: nil}}), do: nil

  defp temp_address(%{assigns: %{temp_email: %{} = email}}),
    do: email[:address] || email["address"]

  defp format_ttl(seconds) do
    minutes = div(seconds || 0, 60)
    secs = rem(seconds || 0, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(secs), 2, "0")}"
  end

  defp format_received(nil), do: ""

  defp format_received(value) when is_integer(value) do
    value
    |> DateTime.from_unix!(:millisecond)
    |> Calendar.strftime("%b %-d, %H:%M")
  rescue
    _ -> ""
  end

  defp format_received(value) when is_binary(value), do: value

  defp email_initial(email) do
    email |> Map.get("from", "M") |> String.first() |> Kernel.||("M") |> String.upcase()
  end

  defp email_preview(email) do
    text = Map.get(email, "text") || Map.get(email, "html") || ""
    String.slice(text, 0, 100)
  end

  defp dashboard_path("en", href), do: href
  defp dashboard_path(nil, href), do: href
  defp dashboard_path(locale, href), do: "/#{locale}#{href}"
end
