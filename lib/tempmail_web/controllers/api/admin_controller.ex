defmodule TempmailWeb.Api.AdminController do
  use TempmailWeb, :controller

  alias Tempmail.{Accounts, Mail}

  plug :require_admin

  def domains(conn, _params), do: json(conn, %{success: true, domains: Mail.list_domains()})

  def create_domain(conn, params) do
    case Mail.create_domain(params) do
      {:ok, domain} ->
        json(conn, %{success: true, domain: domain})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def users(conn, _params), do: json(conn, %{success: true, users: Accounts.list_users()})

  def analytics(conn, params) do
    days = params |> Map.get("days", "14") |> String.to_integer()
    json(conn, %{success: true, stats: Mail.recent_stats(days)})
  end

  defp require_admin(conn, _opts) do
    if Accounts.admin?(conn.assigns[:current_user]) do
      conn
    else
      conn |> put_status(:forbidden) |> json(%{success: false, error: "Forbidden"}) |> halt()
    end
  end
end
