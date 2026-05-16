defmodule TempmailWeb.AdminDomainsLive do
  use TempmailWeb, :live_view

  alias Tempmail.{Accounts, Mail}

  @impl true
  def mount(params, _session, socket) do
    if Accounts.admin?(socket.assigns.current_user) do
      {:ok,
       socket
       |> assign(:page_title, "Admin Domains")
       |> assign(:locale, Map.get(params, "locale", "en"))
       |> assign(:domains, Mail.list_domains())
       |> assign(:form, to_form(%{"domain" => "", "description" => ""}))
       |> assign(:error, nil)}
    else
      {:ok, push_navigate(socket, to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("create", params, socket) do
    case Mail.create_domain(params) do
      {:ok, _domain} ->
        {:noreply, assign(socket, :domains, Mail.list_domains())}

      {:error, changeset} ->
        {:noreply,
         assign(socket, :error, "Could not create domain: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    domain = Mail.get_domain!(id)
    Mail.update_domain(domain, %{is_active: !domain.is_active})
    {:noreply, assign(socket, :domains, Mail.list_domains())}
  end

  def handle_event("default", %{"id" => id}, socket) do
    id |> Mail.get_domain!() |> Mail.set_default_domain()
    {:noreply, assign(socket, :domains, Mail.list_domains())}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    domain = Mail.get_domain!(id)

    case Mail.delete_domain(domain, socket.assigns.current_user) do
      {:ok, _} -> {:noreply, assign(socket, :domains, Mail.list_domains())}
      {:error, _} -> {:noreply, assign(socket, :error, "Could not delete domain")}
    end
  end
end
