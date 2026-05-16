defmodule TempmailWeb.Api.EmailController do
  use TempmailWeb, :controller

  alias Tempmail.Mail

  def generate(conn, params) do
    case Mail.create_temp_email(params) do
      {:ok, email} ->
        json(conn, %{success: true, email: email})

      _ ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{success: false, error: "Failed to generate email"})
    end
  end

  def inbox(conn, %{"address" => address}) do
    with {:ok, _temp_email} <- Mail.get_temp_email(address),
         {:ok, emails} <- Mail.get_inbox(address) do
      json(conn, %{success: true, emails: emails})
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Email address expired or not found"})
    end
  end

  def inbox(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{success: false, error: "Address is required"})

  def refresh(conn, %{"address" => address}) do
    case Mail.refresh_temp_email(address) do
      {:ok, email} ->
        json(conn, %{success: true, email: email})

      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Email address expired or not found"})
    end
  end

  def mark_read(conn, %{"address" => address, "emailId" => id}) do
    case Mail.mark_temp_email_read(address, id) do
      {:ok, _} -> json(conn, %{success: true})
      _ -> conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})
    end
  end

  def delete(conn, %{"address" => address, "emailId" => id}) do
    case Mail.delete_temp_email(address, id) do
      {:ok, _} -> json(conn, %{success: true})
      _ -> conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})
    end
  end

  def extend(conn, %{"address" => address, "makePermanent" => true}) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{success: false, error: "You must be logged in to create a permanent mailbox"})

      user ->
        case Mail.promote_temp_email(user, address) do
          {:ok, mailbox} ->
            json(conn, %{
              success: true,
              permanent: true,
              mailbox: %{id: mailbox.id, address: mailbox.address}
            })

          {:error, :reserved_prefix} ->
            conn
            |> put_status(:bad_request)
            |> json(%{success: false, error: "Reserved email prefix"})

          _ ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{success: false, error: "Failed to save mailbox"})
        end
    end
  end

  def extend(conn, %{"address" => address} = params) do
    case Mail.extend_temp_email(address, Map.get(params, "duration"), conn.assigns[:current_user]) do
      {:ok, email} ->
        json(conn, %{success: true, permanent: false, email: email})

      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Email address not found or already expired"})
    end
  end
end
