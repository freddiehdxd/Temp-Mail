defmodule TempmailWeb.Api.WebhookController do
  use TempmailWeb, :controller

  alias Tempmail.Mail

  plug TempmailWeb.Plugs.WebhookAuth

  def mailcow(conn, params) do
    case Mail.route_incoming_email(params) do
      {:ok, %{__struct__: Tempmail.Mail.UserEmail}} ->
        json(conn, %{success: true, storage: "persistent"})

      {:ok, _message} ->
        json(conn, %{success: true, storage: "temporary"})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{success: false, error: "Recipient not found"})

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Webhook processing failed"})
    end
  end
end
