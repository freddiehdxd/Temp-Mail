defmodule TempmailWeb.RobotsController do
  use TempmailWeb, :controller

  @base_url "https://tempmailcentral.com"

  def index(conn, _params) do
    robots = """
    User-agent: *
    Allow: /
    Disallow: /api/
    Disallow: /admin/
    Disallow: /dashboard/
    Disallow: /auth/
    Disallow: /users/
    Disallow: /dev/

    Sitemap: #{@base_url}/sitemap.xml
    """

    conn |> put_resp_content_type("text/plain") |> send_resp(200, robots)
  end
end
