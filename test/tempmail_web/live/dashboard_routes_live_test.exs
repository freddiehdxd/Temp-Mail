defmodule TempmailWeb.DashboardRoutesLiveTest do
  use TempmailWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tempmail.AccountsFixtures

  alias Tempmail.Mail.UserDomain
  alias Tempmail.{Accounts, Content, Mail, Repo}

  describe "user dashboard routes" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders all user dashboard pages", %{conn: conn} do
      for {path, text} <- [
            {~p"/dashboard", "Welcome"},
            {~p"/dashboard/mailboxes", "My Mailboxes"},
            {~p"/dashboard/domains", "Custom Domains"},
            {~p"/dashboard/temp", "Current Temporary Address"},
            {~p"/dashboard/starred", "Starred"},
            {~p"/dashboard/archived", "Archived"},
            {~p"/dashboard/settings", "Email Preferences"}
          ] do
        {:ok, _lv, html} = live(conn, path)
        assert html =~ text
      end
    end

    test "renders localized user dashboard pages", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/es/dashboard")
      assert html =~ "My Mailboxes"
    end

    test "custom domains can be added and removed", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/dashboard/domains")
      domain = "user#{System.unique_integer([:positive])}.example.com"

      html =
        lv
        |> form("form", %{domain: domain})
        |> render_submit()

      assert html =~ domain
      assert [user_domain] = Mail.list_user_domains(user)

      html =
        lv
        |> element("button[phx-click='delete'][phx-value-id='#{user_domain.id}']")
        |> render_click()

      refute html =~ domain
      assert Mail.list_user_domains(user) == []
    end

    test "custom domains cannot claim system or already claimed domains", %{user: user} do
      system_domain = "system#{System.unique_integer([:positive])}.example.com"
      claimed_domain = "claimed#{System.unique_integer([:positive])}.example.com"
      other_user = user_fixture()

      assert {:ok, _domain} =
               Mail.create_domain(%{domain: system_domain, is_active: true, is_default: false})

      assert {:error, :system_domain} =
               Mail.create_user_domain(user, %{"domain" => system_domain})

      assert {:ok, _user_domain} = Mail.create_user_domain(user, %{"domain" => claimed_domain})

      assert {:error, :domain_claimed} =
               Mail.create_user_domain(other_user, %{"domain" => claimed_domain})
    end

    test "mailboxes require verified custom domains and protect domains in use", %{user: user} do
      domain = "verified#{System.unique_integer([:positive])}.example.com"
      assert {:ok, user_domain} = Mail.create_user_domain(user, %{"domain" => domain})

      assert {:error, :domain_not_verified} =
               Mail.create_user_mailbox(user, %{"prefix" => "first", "domain" => domain})

      assert {:ok, verified_domain} =
               user_domain
               |> UserDomain.changeset(%{is_verified: true, mx_verified: true})
               |> Repo.update()

      assert {:ok, mailbox} =
               Mail.create_user_mailbox(user, %{"prefix" => "first", "domain" => domain})

      assert mailbox.address == "first@#{domain}"
      assert {:error, {:domain_in_use, 1}} = Mail.delete_user_domain(user, verified_domain.id)
    end
  end

  describe "admin dashboard routes" do
    setup %{conn: conn} do
      user = user_fixture()
      {:ok, admin} = Accounts.update_user_role(user, "SUPER_ADMIN")
      %{conn: log_in_user(conn, admin), user: admin}
    end

    test "renders all admin pages", %{conn: conn} do
      for {path, text} <- [
            {~p"/admin", "Quick Actions"},
            {~p"/admin/domains", "System Domains"},
            {~p"/admin/users", "All Users"},
            {~p"/admin/blog", "New Post"},
            {~p"/admin/blog/categories", "New Category"},
            {~p"/admin/blog/new", "Create New Post"},
            {~p"/admin/analytics", "Email Activity Trend"},
            {~p"/admin/settings", "Mailcow Configuration"}
          ] do
        {:ok, _lv, html} = live(conn, path)
        assert html =~ text
      end
    end

    test "renders localized admin pages", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/es/admin")
      assert html =~ "Quick Actions"
    end

    test "renders admin blog edit page", %{conn: conn, user: user} do
      {:ok, post} =
        Content.upsert_post(%{
          "slug" => "test-post",
          "status" => "DRAFT",
          "author_id" => user.id,
          "translations" => %{
            "en" => %{
              "title" => "Test Post",
              "excerpt" => "Excerpt",
              "content" => "Content"
            }
          }
        })

      {:ok, _lv, html} = live(conn, ~p"/admin/blog/#{post.id}")
      assert html =~ "Edit Post"
      assert html =~ "Test Post"
    end
  end

  describe "auth compatibility routes" do
    test "auth signin redirects to Phoenix login", %{conn: conn} do
      conn = get(conn, ~p"/auth/signin")
      assert redirected_to(conn) == ~p"/users/log_in"
    end

    test "auth error page renders next auth compatible errors", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/auth/error?error=OAuthCallback")
      assert html =~ "Authentication Error"
      assert html =~ "Error handling the response from the OAuth provider"
    end
  end
end
