defmodule TempmailWeb.Plugs.ValidateLocale do
  @moduledoc """
  Returns a real 404 for `/:locale/...` routes whose locale segment is not a
  supported language. Without this, the catch-all locale scope renders the
  homepage for any junk single-segment path (soft 404s for crawlers, and
  broken asset URLs silently returning HTML).
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{path_params: %{"locale" => locale}} = conn, _opts) do
    if locale in TempmailWeb.I18n.supported_locales() do
      conn
    else
      conn
      |> put_status(:not_found)
      |> Phoenix.Controller.put_root_layout(false)
      |> Phoenix.Controller.put_view(TempmailWeb.ErrorHTML)
      |> Phoenix.Controller.render("404.html")
      |> halt()
    end
  end

  def call(conn, _opts), do: conn
end
