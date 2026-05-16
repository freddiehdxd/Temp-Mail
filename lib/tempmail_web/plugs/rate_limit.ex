defmodule TempmailWeb.Plugs.RateLimit do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    key = "#{opts[:action]}:#{client_ip(conn)}"
    scale_ms = Keyword.get(opts, :scale_ms, 60_000)
    limit = Keyword.get(opts, :limit, 30)

    case Hammer.check_rate(key, scale_ms, limit) do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        conn
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{success: false, error: "Rate limit exceeded. Try again later."})
        |> halt()
    end
  end

  defp client_ip(conn) do
    forwarded = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))

    if forwarded do
      forwarded |> String.split(",") |> List.first() |> String.trim()
    else
      conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
