defmodule TempmailWeb.UserDomainsLive do
  use TempmailWeb, :live_view

  alias Tempmail.Mail

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Custom Domains")
     |> assign(:locale, Map.get(params, "locale", "en"))
     |> assign(:domains, Mail.list_user_domains(socket.assigns.current_user))
     |> assign(:form, to_form(%{"domain" => ""}))
     |> assign(:verification_results, %{})
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("create", %{"domain" => domain}, socket) do
    case Mail.create_user_domain(socket.assigns.current_user, %{"domain" => domain}) do
      {:ok, _domain} ->
        {:noreply,
         socket
         |> assign(:domains, Mail.list_user_domains(socket.assigns.current_user))
         |> assign(:form, to_form(%{"domain" => ""}))
         |> assign(:error, nil)}

      {:error, reason} when reason in [:system_domain, :domain_claimed, :domain_limit] ->
        {:noreply, assign(socket, :error, domain_error(reason))}

      {:error, changeset} ->
        {:noreply, assign(socket, :error, "Could not add domain: #{inspect(changeset.errors)}")}
    end
  end

  def handle_event("verify", %{"id" => id}, socket) do
    domain = Enum.find(socket.assigns.domains, &(&1.id == id))

    verification_results =
      if domain do
        case Mail.verify_user_domain(domain) do
          {:ok, _domain, results} -> Map.put(socket.assigns.verification_results, id, results)
          _ -> socket.assigns.verification_results
        end
      else
        socket.assigns.verification_results
      end

    {:noreply,
     socket
     |> assign(:domains, Mail.list_user_domains(socket.assigns.current_user))
     |> assign(:verification_results, verification_results)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    case Mail.delete_user_domain(socket.assigns.current_user, id) do
      {:ok, _domain} ->
        {:noreply,
         socket
         |> assign(:domains, Mail.list_user_domains(socket.assigns.current_user))
         |> assign(:error, nil)}

      {:error, {:domain_in_use, count}} ->
        {:noreply,
         assign(
           socket,
           :error,
           "Cannot delete domain. #{count} mailbox(es) are using this domain."
         )}

      _ ->
        {:noreply, assign(socket, :error, "Could not delete domain.")}
    end
  end

  defp domain_error(:system_domain),
    do: "This domain is already a system domain and cannot be claimed."

  defp domain_error(:domain_claimed), do: "This domain has already been claimed by another user."
  defp domain_error(:domain_limit), do: "Maximum custom domains reached."
end
