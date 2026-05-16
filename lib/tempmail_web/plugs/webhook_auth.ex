defmodule TempmailWeb.Plugs.WebhookAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    secret = Application.get_env(:tempmail, :webhook_secret, "")

    if secret == "" do
      conn
    else
      with [signature] <- get_req_header(conn, "x-webhook-signature"),
           body when is_binary(body) <- conn.assigns[:raw_body],
           expected <- :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower),
           true <- Plug.Crypto.secure_compare(signature, expected) do
        conn
      else
        _ ->
          conn
          |> put_status(:unauthorized)
          |> Phoenix.Controller.json(%{success: false, error: "Invalid webhook signature"})
          |> halt()
      end
    end
  end
end
