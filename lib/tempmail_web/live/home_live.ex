defmodule TempmailWeb.HomeLive do
  use TempmailWeb, :live_view

  import TempmailWeb.EmailHelpers

  alias Tempmail.Mail

  @impl true
  def mount(params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    socket =
      socket
      |> assign(:locale, locale)
      |> assign(:html_lang, locale)
      |> assign(:temp_email, nil)
      |> assign(:emails, [])
      |> assign(:selected_email, nil)
      |> assign(:ttl, 0)
      |> assign(:domains, Mail.list_active_domains())
      |> assign(:copied, false)
      |> assign(:error, nil)
      |> assign(:tick_ref, nil)
      |> assign(:seo_page, :home)
      |> assign(:total_stats, Mail.total_stats())
      |> assign(
        :page_title,
        TempmailWeb.I18n.t(
          locale,
          "home.title",
          "Free Temporary Email - Disposable Inbox in Seconds"
        )
      )
      |> assign(
        :meta_description,
        TempmailWeb.I18n.t(
          locale,
          "home.description",
          "Generate a free temporary email address that deletes itself after 10 minutes - or keep it up to 30 days with a free account. Real-time inbox, no registration."
        )
      )
      |> assign(
        :og_title,
        TempmailWeb.I18n.t(
          locale,
          "home.title",
          "Free Temporary Email - Disposable Inbox in Seconds"
        )
      )
      |> assign(
        :og_description,
        TempmailWeb.I18n.t(
          locale,
          "home.description",
          "Generate a free temporary email address that deletes itself after 10 minutes - or keep it up to 30 days with a free account."
        )
      )
      |> assign(
        :og_url,
        if(locale == "en",
          do: "https://tempmailcentral.com/",
          else: "https://tempmailcentral.com/#{locale}"
        )
      )
      |> assign(
        :canonical_url,
        if(locale == "en",
          do: "https://tempmailcentral.com/",
          else: "https://tempmailcentral.com/#{locale}"
        )
      )
      |> assign(:og_locale, og_locale(locale))
      |> assign(:hreflang, build_hreflang(""))

    # On the initial HTTP render create the address right away so it is visible
    # before any JS runs. The client hook hands it back on the connected mount
    # (unless localStorage already holds a live address), so it is not wasted.
    socket = if connected?(socket), do: socket, else: generate_temp_email(socket)

    {:ok, socket}
  end

  @impl true
  def handle_event("restore_or_generate", %{"address" => address}, socket)
      when is_binary(address) and address != "" do
    case Mail.get_temp_email(address) do
      {:ok, temp_email} ->
        Phoenix.PubSub.subscribe(Tempmail.PubSub, Mail.inbox_topic(address))
        {:ok, emails} = Mail.get_inbox(address)

        if ref = socket.assigns[:tick_ref], do: Process.cancel_timer(ref)
        ttl = temp_email["ttl"] || 0
        tick_ref = if ttl > 0, do: Process.send_after(self(), :tick, 1_000)

        {:noreply,
         socket
         |> assign(:temp_email, temp_email)
         |> assign(:emails, emails)
         |> assign(:selected_email, nil)
         |> assign(:ttl, ttl)
         |> assign(:error, nil)
         |> assign(:tick_ref, tick_ref)}

      _ ->
        {:noreply, generate_temp_email(socket)}
    end
  end

  def handle_event("restore_or_generate", _params, socket) do
    {:noreply, generate_temp_email(socket)}
  end

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
       |> assign(:ttl, temp_email["ttl"] || temp_email[:ttl])}
    else
      _ -> {:noreply, assign(socket, :error, "Failed to extend this address.")}
    end
  end

  def handle_event("save", _params, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, push_navigate(socket, to: ~p"/users/log_in")}
  end

  def handle_event("save", _params, socket) do
    with address when is_binary(address) <- temp_address(socket),
         {:ok, _mailbox} <- Mail.promote_temp_email(socket.assigns.current_user, address) do
      {:noreply, push_navigate(socket, to: ~p"/dashboard/mailboxes")}
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

    if email && temp_address(socket) do
      Mail.mark_temp_email_read(temp_address(socket), id)
    end

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
    tick_ref = Process.send_after(self(), :tick, 1_000)
    {:noreply, socket |> assign(:ttl, ttl - 1) |> assign(:tick_ref, tick_ref)}
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
        if connected?(socket),
          do: Phoenix.PubSub.subscribe(Tempmail.PubSub, Mail.inbox_topic(temp_email.address))

        if ref = socket.assigns[:tick_ref], do: Process.cancel_timer(ref)
        tick_ref = if connected?(socket), do: Process.send_after(self(), :tick, 1_000)

        socket
        |> push_event("tempmail_created", %{address: temp_email.address})
        |> assign(:temp_email, temp_email)
        |> assign(:emails, [])
        |> assign(:selected_email, nil)
        |> assign(:ttl, temp_email.ttl)
        |> assign(:error, nil)
        |> assign(:tick_ref, tick_ref)

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

  defp temp_address(%{temp_email: nil}), do: nil
  defp temp_address(%{temp_email: %{} = email}), do: email[:address] || email["address"]

  defp format_ttl(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
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
    email
    |> Map.get("from", "M")
    |> String.first()
    |> Kernel.||("M")
    |> String.upcase()
  end

  @base_url "https://tempmailcentral.com"
  @locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)

  defp build_hreflang(path) do
    [{"x-default", "#{@base_url}#{if path == "", do: "/", else: path}"}] ++
      Enum.map(@locales, fn
        "en" -> {"en", "#{@base_url}#{if path == "", do: "/", else: path}"}
        loc -> {loc, "#{@base_url}/#{loc}#{path}"}
      end)
  end

  defp og_locale(locale) do
    Map.get(
      %{
        "en" => "en_US",
        "es" => "es_ES",
        "fr" => "fr_FR",
        "de" => "de_DE",
        "pt" => "pt_BR",
        "zh" => "zh_CN",
        "ja" => "ja_JP",
        "ar" => "ar_SA",
        "ru" => "ru_RU",
        "hi" => "hi_IN",
        "ko" => "ko_KR",
        "it" => "it_IT",
        "nl" => "nl_NL",
        "tr" => "tr_TR",
        "pl" => "pl_PL",
        "vi" => "vi_VN",
        "th" => "th_TH",
        "id" => "id_ID",
        "sv" => "sv_SE",
        "el" => "el_GR"
      },
      locale,
      "en_US"
    )
  end

  defp format_count(n) when is_integer(n) and n >= 1000 do
    n
    |> div(1000)
    |> Kernel.*(1000)
    |> Integer.to_string()
    |> String.replace(~r/(\d)(?=(\d{3})+$)/, "\\1,")
  end

  defp format_count(n), do: Integer.to_string(n)
end
