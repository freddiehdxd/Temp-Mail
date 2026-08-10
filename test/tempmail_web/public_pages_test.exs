defmodule TempmailWeb.PublicPagesTest do
  use TempmailWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Tempmail.Repo
  alias Tempmail.Support.ContactMessage

  describe "homepage" do
    test "dead render (what crawlers see) has no error banners or fabricated claims", %{
      conn: conn
    } do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      refute html =~ "find the internet"
      refute html =~ "Something went wrong!"
      refute html =~ "Attempting to reconnect"
      refute html =~ "500,000"
      refute html =~ "10M+"
      refute html =~ "99.9%"
      refute html =~ "TempMailCentral"

      assert html =~ "How TempMail Central Actually Works"
      assert html =~ "Temporary vs. permanent inbox"
    end

    test "connected clients still get reconnect banners", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Attempting to reconnect"
    end

    test "has canonical, hreflang with x-default, and unique title", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ ~s(rel="canonical" href="https://tempmailcentral.com/")
      assert html =~ ~s(hreflang="x-default")
      assert html =~ "| TempMail Central</title>"
    end

    test "structured data contains no review markup", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      refute html =~ "aggregateRating"
      refute html =~ "ratingValue"
    end
  end

  describe "static pages" do
    test "about page has substantial content", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/about")

      assert html =~ "About TempMail Central"
      assert html =~ "Who operates the service"
      assert html =~ "independent, privately operated"
      assert html =~ "Support"
    end

    test "privacy page covers collection, cookies, retention, ads, deletion", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/privacy")

      assert html =~ "Privacy Policy"
      assert html =~ "Cookies and local storage"
      assert html =~ "Google AdSense"
      assert html =~ "How long data is kept"
      assert html =~ "Deleting data and your rights"
      assert html =~ "contact@tempmailcentral.com"
    end

    test "terms page covers acceptable use, prohibitions, termination", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/terms")

      assert html =~ "Terms of Service"
      assert html =~ "Acceptable use"
      assert html =~ "Prohibited activity"
      assert html =~ "Termination"
    end

    test "locale variants canonicalize to the English URL", %{conn: conn} do
      conn = get(conn, "/es/privacy")
      html = html_response(conn, 200)

      assert html =~ ~s(rel="canonical" href="https://tempmailcentral.com/privacy")
    end
  end

  describe "contact page" do
    test "renders the form and support email", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contact")

      assert html =~ "Contact us"
      assert html =~ "contact@tempmailcentral.com"
      assert html =~ "contact-form"
    end

    test "stores a valid submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      html =
        view
        |> form("#contact-form", %{
          "contact_message" => %{
            "name" => "Test Person",
            "email" => "person@example.com",
            "topic" => "support",
            "body" => "This is a sufficiently long test message."
          }
        })
        |> render_submit()

      assert html =~ "Message received"

      assert [message] = Repo.all(ContactMessage)
      assert message.body =~ "sufficiently long"
      assert message.email == "person@example.com"
    end

    test "rejects a too-short message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      html =
        view
        |> form("#contact-form", %{
          "contact_message" => %{"topic" => "support", "body" => "short"}
        })
        |> render_submit()

      assert html =~ "should be between 10 and 5000 characters"
      assert Repo.all(ContactMessage) == []
    end

    test "silently drops honeypot submissions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      html =
        view
        |> form("#contact-form", %{
          "contact_message" => %{"topic" => "support", "body" => "I am a robot beep boop."},
          "website" => "https://spam.example"
        })
        |> render_submit()

      assert html =~ "Message received"
      assert Repo.all(ContactMessage) == []
    end
  end

  describe "robots and sitemap" do
    test "robots.txt is served by the controller with a sitemap reference", %{conn: conn} do
      conn = get(conn, ~p"/robots.txt")
      body = text_response(conn, 200)

      assert body =~ "Sitemap: https://tempmailcentral.com/sitemap.xml"
      assert body =~ "Disallow: /dashboard/"
      assert body =~ "Allow: /"
    end

    test "sitemap lists canonical pages only", %{conn: conn} do
      conn = get(conn, ~p"/sitemap.xml")
      body = response(conn, 200)

      assert body =~ "https://tempmailcentral.com/</loc>"
      assert body =~ "https://tempmailcentral.com/about</loc>"
      assert body =~ "https://tempmailcentral.com/contact</loc>"
      assert body =~ ~s(hreflang="x-default")
      # Untranslated locale variants of legal pages must not be listed.
      refute body =~ "/es/privacy"
      refute body =~ "/de/terms"
    end
  end

  describe "blog" do
    test "seeded articles are listed and render with full content", %{conn: conn} do
      Tempmail.Content.BlogSeeds.run()

      {:ok, _view, listing} = live(conn, ~p"/blog")
      assert listing =~ "How temporary inbox deletion actually works"

      {:ok, _view, article} = live(conn, ~p"/blog/how-temporary-inbox-deletion-works")
      assert article =~ "Redis"
      assert article =~ "min read"

      # Locale variant falls back to English content and canonicalizes to EN.
      conn2 = get(conn, "/fr/blog/how-temporary-inbox-deletion-works")
      html = html_response(conn2, 200)

      assert html =~
               ~s(rel="canonical" href="https://tempmailcentral.com/blog/how-temporary-inbox-deletion-works")
    end

    test "seeding is idempotent", %{conn: _conn} do
      Tempmail.Content.BlogSeeds.run()
      first = Repo.aggregate(Tempmail.Content.BlogPost, :count)
      Tempmail.Content.BlogSeeds.run()
      assert Repo.aggregate(Tempmail.Content.BlogPost, :count) == first
      assert first == 10
    end
  end

  describe "locale catch-all" do
    test "unknown single-segment paths 404 instead of soft-rendering the homepage", %{conn: conn} do
      assert conn |> get("/favicon-deadbeef.ico") |> response(404)
      assert conn |> get("/notalocale") |> response(404)
    end

    test "real locales still render", %{conn: conn} do
      conn = get(conn, "/es")
      assert html_response(conn, 200) =~ "Correo Temporal"
    end
  end

  describe "auth pages" do
    test "login page is noindex", %{conn: conn} do
      conn = get(conn, ~p"/users/log_in")
      html = html_response(conn, 200)

      assert html =~ ~s(<meta name="robots" content="noindex")
    end
  end
end
