defmodule TempmailWeb.ContactLive do
  use TempmailWeb, :live_view

  alias Tempmail.Support
  alias Tempmail.Support.ContactMessage

  @base_url "https://tempmailcentral.com"

  # 5 submissions per hour per IP.
  @rate_scale_ms 60 * 60 * 1000
  @rate_limit 5

  @impl true
  def mount(params, _session, socket) do
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)

    {:ok,
     socket
     |> assign(:locale, locale)
     |> assign(:html_lang, "en")
     |> assign(:page_title, "Contact Us")
     |> assign(
       :meta_description,
       "Contact the TempMail Central team: support questions, privacy requests, abuse reports, and feedback. We read every message that comes through this form."
     )
     |> assign(:canonical_url, "#{@base_url}/contact")
     |> assign(:client_ip, client_ip(socket))
     |> assign(:sent, false)
     |> assign(:form, to_form(Support.change_contact_message(%ContactMessage{})))}
  end

  @impl true
  def handle_event("validate", %{"contact_message" => params}, socket) do
    changeset =
      %ContactMessage{}
      |> Support.change_contact_message(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("submit", %{"contact_message" => params} = all_params, socket) do
    cond do
      # Honeypot field filled in - almost certainly a bot. Pretend success.
      Map.get(all_params, "website", "") != "" ->
        {:noreply, assign(socket, :sent, true)}

      rate_limited?(socket.assigns.client_ip) ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Too many messages from your connection. Please try again later."
         )}

      true ->
        params = Map.put(params, "ip_address", socket.assigns.client_ip)

        case Support.create_contact_message(params) do
          {:ok, _message} ->
            {:noreply, assign(socket, :sent, true)}

          {:error, changeset} ->
            {:noreply, assign(socket, :form, to_form(changeset))}
        end
    end
  end

  def handle_event("another", _params, socket) do
    {:noreply,
     socket
     |> assign(:sent, false)
     |> assign(:form, to_form(Support.change_contact_message(%ContactMessage{})))}
  end

  defp rate_limited?(ip) do
    case Hammer.check_rate("contact:#{ip}", @rate_scale_ms, @rate_limit) do
      {:allow, _count} -> false
      {:deny, _limit} -> true
    end
  end

  defp client_ip(socket) do
    x_headers = get_connect_info(socket, :x_headers) || []

    forwarded =
      Enum.find_value(x_headers, fn
        {"x-forwarded-for", value} -> value |> String.split(",") |> List.first() |> String.trim()
        _ -> nil
      end)

    cond do
      forwarded ->
        forwarded

      peer = get_connect_info(socket, :peer_data) ->
        peer.address |> :inet.ntoa() |> to_string()

      true ->
        "unknown"
    end
  end
end
