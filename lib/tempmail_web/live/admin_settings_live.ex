defmodule TempmailWeb.AdminSettingsLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Mail}

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:page_title, "Settings")
       |> assign(:locale, Map.get(params, "locale", "en"))
       |> assign(:saved, false)
       |> assign(:form, to_form(settings_map()))}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("save", params, socket) do
    Mail.upsert_setting("emailTTL", Map.get(params, "emailTTL", "600"), "number")
    Mail.upsert_setting("mailcowUrl", Map.get(params, "mailcowUrl", ""), "string")
    Mail.upsert_setting("mailcowKey", Map.get(params, "mailcowKey", ""), "secret")

    {:noreply, socket |> assign(:saved, true) |> assign(:form, to_form(settings_map()))}
  end

  def handle_event("test_mailcow", _params, socket) do
    {:noreply,
     put_flash(socket, :info, "Mailcow connection test is configured for API implementation.")}
  end

  defp settings_map do
    settings = Map.new(Mail.list_settings(), &{&1.key, &1.value})

    %{
      "emailTTL" =>
        Map.get(
          settings,
          "emailTTL",
          "#{Application.get_env(:tempmail, :default_email_ttl, 600)}"
        ),
      "mailcowUrl" =>
        Map.get(settings, "mailcowUrl", Application.get_env(:tempmail, :mailcow_api_url, "")),
      "mailcowKey" =>
        Map.get(settings, "mailcowKey", Application.get_env(:tempmail, :mailcow_api_key, ""))
    }
  end
end
