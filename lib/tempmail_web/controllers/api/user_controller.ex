defmodule TempmailWeb.Api.UserController do
  use TempmailWeb, :controller

  import Ecto.Query, warn: false
  alias Tempmail.Mail

  plug :require_user

  # --- Emails ---

  def list_emails(conn, params) do
    user = conn.assigns.current_user

    opts = [
      mailbox_id: params["mailbox_id"],
      starred: parse_bool(params["starred"]),
      archived: parse_bool(params["archived"]),
      limit: String.to_integer(params["limit"] || "50")
    ]

    emails = Mail.list_user_emails(user, opts)
    json(conn, %{success: true, emails: Enum.map(emails, &serialize_email/1)})
  end

  def get_email(conn, %{"id" => id}) do
    case Mail.get_user_email(conn.assigns.current_user, id) do
      nil -> conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})
      email -> json(conn, %{success: true, email: serialize_email(email)})
    end
  end

  def update_email(conn, %{"id" => id} = params) do
    attrs = Map.take(params, ["read", "starred", "archived"])

    case Mail.update_user_email(conn.assigns.current_user, id, attrs) do
      {:ok, email} -> json(conn, %{success: true, email: serialize_email(email)})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_email(conn, %{"id" => id}) do
    case Mail.delete_user_email(conn.assigns.current_user, id) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})
    end
  end

  # --- Mailboxes ---

  def list_mailboxes(conn, _params) do
    mailboxes = Mail.list_user_mailboxes(conn.assigns.current_user)
    json(conn, %{success: true, mailboxes: Enum.map(mailboxes, &serialize_mailbox/1)})
  end

  def get_mailbox(conn, %{"id" => id}) do
    case Mail.get_user_mailbox(conn.assigns.current_user, id) do
      nil -> conn |> put_status(:not_found) |> json(%{success: false, error: "Mailbox not found"})
      mailbox -> json(conn, %{success: true, mailbox: serialize_mailbox(mailbox)})
    end
  end

  def create_mailbox(conn, params) do
    case Mail.create_user_mailbox(conn.assigns.current_user, params) do
      {:ok, mailbox} -> conn |> put_status(:created) |> json(%{success: true, mailbox: %{id: mailbox.id, address: mailbox.address}})
      {:error, :domain_not_allowed} -> conn |> put_status(:bad_request) |> json(%{success: false, error: "Domain not allowed"})
      {:error, :domain_not_verified} -> conn |> put_status(:bad_request) |> json(%{success: false, error: "Domain not verified yet"})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_mailbox(conn, %{"id" => id}) do
    case Mail.delete_user_mailbox(conn.assigns.current_user, id) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{success: false, error: "Mailbox not found"})
    end
  end

  # --- Domains ---

  def list_domains(conn, _params) do
    domains = Mail.list_user_domains(conn.assigns.current_user)
    json(conn, %{success: true, domains: Enum.map(domains, &serialize_domain/1)})
  end

  def create_domain(conn, params) do
    case Mail.create_user_domain(conn.assigns.current_user, params) do
      {:ok, domain} ->
        conn |> put_status(:created) |> json(%{
          success: true,
          domain: serialize_domain(domain),
          dns_instructions: Tempmail.Integrations.Postfix.dns_instructions(domain.domain)
        })
      {:error, :system_domain} -> conn |> put_status(:conflict) |> json(%{success: false, error: "This is a system domain"})
      {:error, :domain_claimed} -> conn |> put_status(:conflict) |> json(%{success: false, error: "Domain already claimed"})
      {:error, :domain_limit} -> conn |> put_status(:bad_request) |> json(%{success: false, error: "Domain limit reached"})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_domain(conn, %{"id" => id}) do
    case Mail.delete_user_domain(conn.assigns.current_user, id) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{success: false, error: "Domain not found"})
      {:error, {:domain_in_use, count}} -> conn |> put_status(:conflict) |> json(%{success: false, error: "Domain has #{count} active mailboxes"})
    end
  end

  def verify_domain(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %Mail.UserDomain{} = domain <-
           Tempmail.Repo.one(from(d in Mail.UserDomain, where: d.user_id == ^user.id and d.id == ^id)),
         {:ok, updated_domain, results} <- Mail.verify_user_domain(domain) do
      json(conn, %{success: true, domain: serialize_domain(updated_domain), verification: results})
    else
      nil -> conn |> put_status(:not_found) |> json(%{success: false, error: "Domain not found"})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  # --- Helpers ---

  defp require_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn |> put_status(:unauthorized) |> json(%{success: false, error: "Authentication required"}) |> halt()
    end
  end

  defp parse_bool("true"), do: true
  defp parse_bool("false"), do: false
  defp parse_bool(_), do: nil

  defp serialize_email(email) do
    %{id: email.id, from: email.from, from_name: email.from_name, subject: email.subject,
      text: email.text, html: email.html, received_at: email.received_at, read: email.read,
      starred: email.starred, archived: email.archived, mailbox_id: email.mailbox_id}
  end

  defp serialize_mailbox(mailbox) do
    %{id: mailbox.id, address: mailbox.address, prefix: mailbox.prefix, domain: mailbox.domain,
      name: mailbox.name, is_primary: mailbox.is_primary, is_active: mailbox.is_active,
      email_count: length(mailbox.emails || []),
      unread_count: Enum.count(mailbox.emails || [], &(!&1.read))}
  end

  defp serialize_domain(domain) do
    %{id: domain.id, domain: domain.domain, is_verified: domain.is_verified,
      is_active: domain.is_active, mx_verified: domain.mx_verified, spf_verified: domain.spf_verified,
      verification_token: domain.verification_token, verified_at: domain.verified_at}
  end
end
