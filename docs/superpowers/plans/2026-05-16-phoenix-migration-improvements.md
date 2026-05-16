# Phoenix Migration Improvements Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete all 18 missing improvements from the Next.js → Phoenix migration before launch.

**Architecture:** Six independent subsystems: database schema fixes, security hardening, API endpoint completion, feature modules (Postfix + audit logging), SEO, and i18n. Database fixes go first since other tasks depend on correct schemas. Security is next-highest priority. API, features, SEO, and i18n are independent of each other and can be parallelized.

**Tech Stack:** Elixir/Phoenix 1.7, Ecto 3.10, PostgreSQL, Redis (Redix), Gettext, Bandit, Hammer (new dep for rate limiting), CorsPlug (new dep for CORS).

---

## Task 1: Database Schema Fixes (Migration)

**Files:**
- Create: `priv/repo/migrations/20260516200000_fix_schema_types_and_indexes.exs`
- Modify: `lib/tempmail/mail/user_email.ex`
- Modify: `lib/tempmail/mail/audit_log.ex`
- Modify: `lib/tempmail/mail/domain.ex`
- Modify: `lib/tempmail/mail/setting.ex`
- Modify: `lib/tempmail/content/blog_post_translation.ex`
- Modify: `lib/tempmail/content/blog_category_translation.ex`

- [ ] **Step 1: Create the migration**

```elixir
# priv/repo/migrations/20260516200000_fix_schema_types_and_indexes.exs
defmodule Tempmail.Repo.Migrations.FixSchemaTypesAndIndexes do
  use Ecto.Migration

  def change do
    # Fix :string → :text mismatches for large-content columns
    alter table(:settings) do
      modify :value, :text, from: :string
    end

    alter table(:audit_logs) do
      modify :details, :text, from: :string
    end

    # Add missing index on blog_posts.author_id
    create index(:blog_posts, [:author_id])

    # Add missing timestamps to blog_category_translations
    alter table(:blog_category_translations) do
      add :inserted_at, :utc_datetime, default: fragment("NOW()")
      add :updated_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
```

- [ ] **Step 2: Fix Ecto schema field types to match migration `:text` columns**

In `lib/tempmail/mail/user_email.ex`, the `text` and `html` fields are `:string` but the migration column is `:text`. Ecto doesn't distinguish between `:string` and `:text` at the schema level (both map to Elixir strings), so the schema types are fine as-is. However, `Setting.value` should be documented, and `AuditLog.details` and `Domain.description` are already correct in the migration. No schema changes needed — the migration handles the DB-level fix.

In `lib/tempmail/content/blog_category_translation.ex`, add timestamps:

```elixir
# Add after the field declarations, before the closing `end` of the schema block:
timestamps(type: :utc_datetime)
```

- [ ] **Step 3: Run the migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully, adds index and timestamps, alters column types.

- [ ] **Step 4: Commit**

```bash
git add priv/repo/migrations/20260516200000_fix_schema_types_and_indexes.exs lib/tempmail/content/blog_category_translation.ex
git commit -m "fix: correct DB column types, add missing index and timestamps"
```

---

## Task 2: Webhook HMAC Signature Validation

**Files:**
- Create: `lib/tempmail_web/plugs/webhook_auth.ex`
- Modify: `lib/tempmail_web/controllers/api/webhook_controller.ex`
- Modify: `config/runtime.exs`

- [ ] **Step 1: Add webhook_secret to runtime config**

In `config/runtime.exs`, add inside the top-level config block (line 31, after `mailcow_api_key`):

```elixir
  webhook_secret: System.get_env("WEBHOOK_SECRET") || ""
```

- [ ] **Step 2: Create the webhook auth plug**

```elixir
# lib/tempmail_web/plugs/webhook_auth.ex
defmodule TempmailWeb.Plugs.WebhookAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    secret = Application.get_env(:tempmail, :webhook_secret, "")

    if secret == "" do
      conn
    else
      with [signature] <- get_req_header(conn, "x-webhook-signature"),
           {:ok, body, _conn} <- read_cached_body(conn),
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

  defp read_cached_body(conn) do
    case conn.assigns[:raw_body] do
      nil -> {:error, :no_body}
      body -> {:ok, body, conn}
    end
  end
end
```

- [ ] **Step 3: Cache the raw body for HMAC verification**

In `lib/tempmail_web/endpoint.ex`, update the `Plug.Parsers` to cache the raw body. Replace the existing `Plug.Parsers` block:

```elixir
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    body_reader: {TempmailWeb.CacheBodyReader, :read_body, []},
    json_decoder: Phoenix.json_library()
```

Create a new file:

```elixir
# lib/tempmail_web/cache_body_reader.ex
defmodule TempmailWeb.CacheBodyReader do
  def read_body(conn, opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, opts)
    conn = Plug.Conn.assign(conn, :raw_body, body)
    {:ok, body, conn}
  end
end
```

- [ ] **Step 4: Apply the plug to the webhook controller**

In `lib/tempmail_web/controllers/api/webhook_controller.ex`, add the plug after the module definition:

```elixir
defmodule TempmailWeb.Api.WebhookController do
  use TempmailWeb, :controller

  alias Tempmail.Mail

  plug TempmailWeb.Plugs.WebhookAuth

  # ... rest of the module unchanged
end
```

- [ ] **Step 5: Commit**

```bash
git add lib/tempmail_web/plugs/webhook_auth.ex lib/tempmail_web/cache_body_reader.ex lib/tempmail_web/controllers/api/webhook_controller.ex lib/tempmail_web/endpoint.ex config/runtime.exs
git commit -m "feat: add HMAC signature validation for webhook endpoint"
```

---

## Task 3: Admin Authorization on LiveView Routes

**Files:**
- Modify: `lib/tempmail_web/user_auth.ex`
- Modify: `lib/tempmail_web/router.ex`

- [ ] **Step 1: Add an `ensure_admin` on_mount callback to UserAuth**

In `lib/tempmail_web/user_auth.ex`, add after the `on_mount(:ensure_authenticated, ...)` function (after line 165):

```elixir
  def on_mount(:ensure_admin, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user && Accounts.admin?(socket.assigns.current_user) do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must be an admin to access this page.")
        |> Phoenix.LiveView.redirect(to: ~p"/")

      {:halt, socket}
    end
  end
```

- [ ] **Step 2: Split admin routes into their own live_session with the admin guard**

In `lib/tempmail_web/router.ex`, replace the `require_authenticated_user` live_session block (lines 100-124) with two blocks — one for user routes and one for admin routes:

```elixir
  scope "/", TempmailWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{TempmailWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive, :index
      live "/dashboard/mailboxes", MailboxesLive, :index
      live "/dashboard/domains", UserDomainsLive, :index
      live "/dashboard/temp", DashboardTempLive, :index
      live "/dashboard/starred", DashboardEmailsLive, :starred
      live "/dashboard/archived", DashboardEmailsLive, :archived
      live "/dashboard/settings", DashboardSettingsLive, :index
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end

    live_session :require_admin,
      on_mount: [{TempmailWeb.UserAuth, :ensure_admin}] do
      live "/admin", AdminLive, :index
      live "/admin/domains", AdminDomainsLive, :index
      live "/admin/users", AdminUsersLive, :index
      live "/admin/blog", AdminBlogLive, :index
      live "/admin/blog/categories", AdminBlogLive, :categories
      live "/admin/blog/new", AdminBlogEditorLive, :new
      live "/admin/blog/:id", AdminBlogEditorLive, :edit
      live "/admin/analytics", AdminAnalyticsLive, :index
      live "/admin/settings", AdminSettingsLive, :index
    end
  end
```

Do the same for the `/:locale` scope (lines 155-177). Split into two live_sessions:

```elixir
  scope "/:locale", TempmailWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :localized_require_authenticated_user,
      on_mount: [{TempmailWeb.UserAuth, :ensure_authenticated}] do
      live "/dashboard", DashboardLive, :index
      live "/dashboard/mailboxes", MailboxesLive, :index
      live "/dashboard/domains", UserDomainsLive, :index
      live "/dashboard/temp", DashboardTempLive, :index
      live "/dashboard/starred", DashboardEmailsLive, :starred
      live "/dashboard/archived", DashboardEmailsLive, :archived
      live "/dashboard/settings", DashboardSettingsLive, :index
    end

    live_session :localized_require_admin,
      on_mount: [{TempmailWeb.UserAuth, :ensure_admin}] do
      live "/admin", AdminLive, :index
      live "/admin/domains", AdminDomainsLive, :index
      live "/admin/users", AdminUsersLive, :index
      live "/admin/blog", AdminBlogLive, :index
      live "/admin/blog/categories", AdminBlogLive, :categories
      live "/admin/blog/new", AdminBlogEditorLive, :new
      live "/admin/blog/:id", AdminBlogEditorLive, :edit
      live "/admin/analytics", AdminAnalyticsLive, :index
      live "/admin/settings", AdminSettingsLive, :index
    end
  end
```

- [ ] **Step 3: Verify the app compiles**

Run: `mix compile --warnings-as-errors`
Expected: Compiles successfully.

- [ ] **Step 4: Commit**

```bash
git add lib/tempmail_web/user_auth.ex lib/tempmail_web/router.ex
git commit -m "feat: add admin authorization guard to all admin LiveView routes"
```

---

## Task 4: Rate Limiting

**Files:**
- Modify: `mix.exs`
- Create: `lib/tempmail_web/plugs/rate_limit.ex`
- Modify: `lib/tempmail_web/router.ex`

- [ ] **Step 1: Add hammer dependency**

In `mix.exs`, add to the `deps` list:

```elixir
      {:hammer, "~> 6.2"},
```

- [ ] **Step 2: Install dependency**

Run: `mix deps.get`

- [ ] **Step 3: Create the rate limit plug**

```elixir
# lib/tempmail_web/plugs/rate_limit.ex
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
```

- [ ] **Step 4: Apply rate limits to API routes in the router**

In `lib/tempmail_web/router.ex`, update the email and webhook pipelines. Add rate-limited pipelines:

```elixir
  pipeline :rate_limit_generate do
    plug TempmailWeb.Plugs.RateLimit, action: "email_generate", scale_ms: 60_000, limit: 10
  end

  pipeline :rate_limit_webhook do
    plug TempmailWeb.Plugs.RateLimit, action: "webhook", scale_ms: 60_000, limit: 120
  end

  pipeline :rate_limit_auth do
    plug TempmailWeb.Plugs.RateLimit, action: "auth", scale_ms: 300_000, limit: 15
  end
```

Apply to routes by splitting the webhook scope:

```elixir
  scope "/api", TempmailWeb.Api do
    pipe_through [:api, :rate_limit_webhook]

    post "/webhook/mailcow", WebhookController, :mailcow
    put "/webhook/mailcow", WebhookController, :mailcow
  end
```

For the email generate endpoint, apply the rate limit plug directly in `EmailController`:

```elixir
  plug TempmailWeb.Plugs.RateLimit, [action: "email_generate", scale_ms: 60_000, limit: 10] when action == :generate
```

For login, apply in `UserSessionController`:

```elixir
  plug TempmailWeb.Plugs.RateLimit, [action: "login", scale_ms: 300_000, limit: 15] when action == :create
```

- [ ] **Step 5: Add Hammer backend to application.ex**

In `lib/tempmail/application.ex`, add `{Hammer.Backend.ETS, []}` or configure the built-in backend. Hammer 6.x uses ETS by default and needs this in `config/config.exs`:

```elixir
config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 300_000 * 10, cleanup_interval_ms: 600_000]}
```

- [ ] **Step 6: Commit**

```bash
git add mix.exs mix.lock lib/tempmail_web/plugs/rate_limit.ex lib/tempmail_web/router.ex config/config.exs lib/tempmail_web/controllers/api/email_controller.ex
git commit -m "feat: add rate limiting to email generation, webhook, and login endpoints"
```

---

## Task 5: Secure .env and Secrets

**Files:**
- Modify: `.gitignore`
- Modify: `.env.example`

- [ ] **Step 1: Add .env to .gitignore**

Append to `.gitignore`:

```
# Environment variables with secrets
.env
.env.local
.env.*.local
```

- [ ] **Step 2: Update .env.example with all required variables**

```bash
# .env.example
DATABASE_URL="postgresql://tempmail_phoenix:tempmail_phoenix@localhost:5432/tempmail_phoenix"
TEST_DATABASE_URL="postgresql://tempmail_phoenix:tempmail_phoenix@localhost:5432/tempmail_phoenix_test"
REDIS_URL="redis://localhost:6379"

# OAuth - Google
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""

# OAuth - Discord
DISCORD_CLIENT_ID=""
DISCORD_CLIENT_SECRET=""

# App Configuration
DEFAULT_EMAIL_TTL=600
DEFAULT_DOMAIN="tempmail.com"
MAIL_SERVER_HOSTNAME="mail.yourdomain.com"
MAX_USER_DOMAINS=5
MAX_USER_MAILBOXES=10

# Webhook authentication (shared with email-parser.py)
WEBHOOK_SECRET=""

# Mailcow API (optional)
MAILCOW_API_URL=""
MAILCOW_API_KEY=""

# DeepL API (for blog translations, optional)
DEEPL_API_KEY=""

# Phoenix
PHX_HOST="localhost"
PORT=4001
SECRET_KEY_BASE=""
```

- [ ] **Step 3: Remove .env from git tracking (if tracked)**

Run: `git rm --cached .env 2>/dev/null; echo done`
Expected: File removed from tracking or "done" if not tracked.

- [ ] **Step 4: Commit**

```bash
git add .gitignore .env.example
git commit -m "fix: add .env to gitignore, update .env.example with all required vars"
```

---

## Task 6: CORS Configuration

**Files:**
- Modify: `mix.exs`
- Modify: `lib/tempmail_web/endpoint.ex`

- [ ] **Step 1: Add cors_plug dependency**

In `mix.exs`, add to deps:

```elixir
      {:cors_plug, "~> 3.0"},
```

- [ ] **Step 2: Install dependency**

Run: `mix deps.get`

- [ ] **Step 3: Add CORSPlug to the endpoint**

In `lib/tempmail_web/endpoint.ex`, add before `plug TempmailWeb.Router`:

```elixir
  plug CORSPlug,
    origin: [
      "https://tempmailcentral.com",
      "http://localhost:4001",
      "http://localhost:3000"
    ],
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    headers: ["Authorization", "Content-Type", "X-Webhook-Signature"]
```

- [ ] **Step 4: Commit**

```bash
git add mix.exs mix.lock lib/tempmail_web/endpoint.ex
git commit -m "feat: add CORS configuration for API endpoints"
```

---

## Task 7: Postfix Integration Module

**Files:**
- Create: `lib/tempmail/integrations/postfix.ex`

- [ ] **Step 1: Create the Postfix integration module**

Port from the old `src/lib/postfix.ts`:

```elixir
# lib/tempmail/integrations/postfix.ex
defmodule Tempmail.Integrations.Postfix do
  @postfix_main_cf "/etc/postfix/main.cf"
  @postfix_transport "/etc/postfix/transport"
  @postfix_virtual_mailbox "/etc/postfix/virtual_mailbox"

  def add_domain(domain) do
    with :ok <- add_to_virtual_domains(domain),
         :ok <- add_to_transport(domain),
         :ok <- add_to_virtual_mailbox(domain),
         :ok <- rebuild_and_reload() do
      {:ok, domain}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def remove_domain(domain) do
    with :ok <- remove_from_virtual_domains(domain),
         :ok <- remove_from_transport(domain),
         :ok <- remove_from_virtual_mailbox(domain),
         :ok <- rebuild_and_reload() do
      {:ok, domain}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  def dns_instructions(domain) do
    hostname = Application.get_env(:tempmail, :mail_server_hostname, "mail.tempmailcentral.com")

    %{
      mx_record: %{type: "MX", name: "@", value: hostname, priority: 10},
      spf_record: %{
        type: "TXT",
        name: "@",
        value: "v=spf1 mx a include:#{hostname} -all"
      },
      dmarc_record: %{
        type: "TXT",
        name: "_dmarc",
        value: "v=DMARC1; p=quarantine; rua=mailto:postmaster@tempmailcentral.com"
      },
      verification_record: %{
        type: "TXT",
        name: "_tempmail-verify",
        value: "will-be-set-per-domain"
      }
    }
  end

  defp add_to_virtual_domains(domain) do
    content = File.read!(@postfix_main_cf)

    case Regex.run(~r/^virtual_mailbox_domains\s*=\s*(.*)$/m, content) do
      [full_match, current_domains] ->
        if String.contains?(current_domains, domain) do
          :ok
        else
          new_domains = "#{String.trim(current_domains)}, #{domain}"
          new_content = String.replace(content, full_match, "virtual_mailbox_domains = #{new_domains}")
          File.write!(@postfix_main_cf, new_content)
          :ok
        end

      nil ->
        File.write!(@postfix_main_cf, content <> "\nvirtual_mailbox_domains = #{domain}\n")
        :ok
    end
  end

  defp add_to_transport(domain) do
    content = File.read!(@postfix_transport)

    if String.contains?(content, domain) do
      :ok
    else
      File.write!(@postfix_transport, String.trim_trailing(content) <> "\n#{domain}    tempmail:\n")
      :ok
    end
  end

  defp add_to_virtual_mailbox(domain) do
    content = File.read!(@postfix_virtual_mailbox)
    escaped = String.replace(domain, ".", "\\.")
    regex_line = "/^.*@#{escaped}$/    OK"

    if String.contains?(content, escaped) do
      :ok
    else
      File.write!(@postfix_virtual_mailbox, String.trim_trailing(content) <> "\n#{regex_line}\n")
      :ok
    end
  end

  defp remove_from_virtual_domains(domain) do
    content = File.read!(@postfix_main_cf)

    case Regex.run(~r/^virtual_mailbox_domains\s*=\s*(.*)$/m, content) do
      [full_match, current_domains] ->
        new_domains =
          current_domains
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == domain))
          |> Enum.join(", ")

        new_content = String.replace(content, full_match, "virtual_mailbox_domains = #{new_domains}")
        File.write!(@postfix_main_cf, new_content)
        :ok

      nil ->
        :ok
    end
  end

  defp remove_from_transport(domain) do
    content = File.read!(@postfix_transport)

    new_content =
      content
      |> String.split("\n")
      |> Enum.reject(&String.starts_with?(&1, domain))
      |> Enum.join("\n")

    File.write!(@postfix_transport, new_content)
    :ok
  end

  defp remove_from_virtual_mailbox(domain) do
    content = File.read!(@postfix_virtual_mailbox)
    escaped = String.replace(domain, ".", "\\.")

    new_content =
      content
      |> String.split("\n")
      |> Enum.reject(&String.contains?(&1, escaped))
      |> Enum.join("\n")

    File.write!(@postfix_virtual_mailbox, new_content)
    :ok
  end

  defp rebuild_and_reload do
    case System.cmd("postmap", [@postfix_transport], stderr_to_stdout: true) do
      {_, 0} ->
        case System.cmd("systemctl", ["reload", "postfix"], stderr_to_stdout: true) do
          {_, 0} -> :ok
          {output, _} -> {:error, "Failed to reload postfix: #{output}"}
        end

      {output, _} ->
        {:error, "Failed to rebuild transport map: #{output}"}
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/tempmail/integrations/postfix.ex
git commit -m "feat: port Postfix integration module from Next.js"
```

---

## Task 8: Audit Logging

**Files:**
- Modify: `lib/tempmail/mail.ex`

- [ ] **Step 1: Add audit logging function to Mail context**

Add to `lib/tempmail/mail.ex`, after the `upsert_setting` function (around line 507):

```elixir
  alias Tempmail.Mail.AuditLog

  def create_audit_log(user, action, target \\ nil, details \\ nil, ip \\ nil) do
    %AuditLog{}
    |> AuditLog.changeset(%{
      user_id: user && user.id,
      action: action,
      target: target,
      details: details,
      ip_address: ip
    })
    |> Repo.insert()
  end

  def list_audit_logs(limit \\ 50) do
    AuditLog
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end
```

- [ ] **Step 2: Wire audit logs into existing admin operations**

In `lib/tempmail/mail.ex`, update `create_domain`, `delete_domain`, and `set_default_domain` to accept an optional user parameter and log:

Update `create_domain`:

```elixir
  def create_domain(attrs, audit_user \\ nil) do
    result =
      %Domain{}
      |> Domain.changeset(attrs)
      |> Repo.insert()

    case {result, audit_user} do
      {{:ok, domain}, %{} = user} ->
        create_audit_log(user, "domain.create", domain.domain)
        result
      _ -> result
    end
  end
```

Update `delete_domain`:

```elixir
  def delete_domain(%Domain{} = domain, audit_user \\ nil) do
    result = Repo.delete(domain)
    case {result, audit_user} do
      {{:ok, _}, %{} = user} -> create_audit_log(user, "domain.delete", domain.domain)
      _ -> :ok
    end
    result
  end
```

In `lib/tempmail/accounts.ex`, update `ban_user` and `update_user_role`:

```elixir
  def ban_user(%User{} = user, reason \\ nil, audit_user \\ nil) do
    result =
      user
      |> Ecto.Changeset.change(
        banned: true,
        banned_at: DateTime.utc_now() |> DateTime.truncate(:second),
        banned_reason: reason
      )
      |> Repo.update()

    case {result, audit_user} do
      {{:ok, _}, %{} = admin} ->
        Tempmail.Mail.create_audit_log(admin, "user.ban", user.email, reason)
      _ -> :ok
    end

    result
  end

  def unban_user(%User{} = user, audit_user \\ nil) do
    result =
      user
      |> Ecto.Changeset.change(banned: false, banned_at: nil, banned_reason: nil)
      |> Repo.update()

    case {result, audit_user} do
      {{:ok, _}, %{} = admin} ->
        Tempmail.Mail.create_audit_log(admin, "user.unban", user.email)
      _ -> :ok
    end

    result
  end

  def update_user_role(%User{} = user, role, audit_user \\ nil) when role in ["USER", "ADMIN", "SUPER_ADMIN"] do
    result = user |> Ecto.Changeset.change(role: role) |> Repo.update()

    case {result, audit_user} do
      {{:ok, _}, %{} = admin} ->
        Tempmail.Mail.create_audit_log(admin, "user.role_change", user.email, "role=#{role}")
      _ -> :ok
    end

    result
  end
```

- [ ] **Step 3: Commit**

```bash
git add lib/tempmail/mail.ex lib/tempmail/accounts.ex
git commit -m "feat: add audit logging for admin operations"
```

---

## Task 9: User API Endpoints (Emails, Mailboxes, Domains)

**Files:**
- Create: `lib/tempmail_web/controllers/api/user_controller.ex`
- Modify: `lib/tempmail_web/router.ex`

- [ ] **Step 1: Create the user API controller**

```elixir
# lib/tempmail_web/controllers/api/user_controller.ex
defmodule TempmailWeb.Api.UserController do
  use TempmailWeb, :controller

  alias Tempmail.{Accounts, Mail}

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

    json(conn, %{
      success: true,
      emails: Enum.map(emails, &serialize_email/1)
    })
  end

  def get_email(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Mail.get_user_email(user, id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})

      email ->
        json(conn, %{success: true, email: serialize_email(email)})
    end
  end

  def update_email(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    attrs = Map.take(params, ["read", "starred", "archived"])

    case Mail.update_user_email(user, id, attrs) do
      {:ok, email} ->
        json(conn, %{success: true, email: serialize_email(email)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_email(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Mail.delete_user_email(user, id) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{success: false, error: "Email not found"})
    end
  end

  # --- Mailboxes ---

  def list_mailboxes(conn, _params) do
    user = conn.assigns.current_user
    mailboxes = Mail.list_user_mailboxes(user)

    json(conn, %{
      success: true,
      mailboxes: Enum.map(mailboxes, &serialize_mailbox/1)
    })
  end

  def get_mailbox(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Mail.get_user_mailbox(user, id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{success: false, error: "Mailbox not found"})

      mailbox ->
        json(conn, %{success: true, mailbox: serialize_mailbox(mailbox)})
    end
  end

  def create_mailbox(conn, params) do
    user = conn.assigns.current_user

    case Mail.create_user_mailbox(user, params) do
      {:ok, mailbox} ->
        conn |> put_status(:created) |> json(%{success: true, mailbox: serialize_mailbox(mailbox)})

      {:error, :domain_not_allowed} ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Domain not allowed"})

      {:error, :domain_not_verified} ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Domain not verified yet"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_mailbox(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Mail.delete_user_mailbox(user, id) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{success: false, error: "Mailbox not found"})
    end
  end

  # --- Domains ---

  def list_domains(conn, _params) do
    user = conn.assigns.current_user
    domains = Mail.list_user_domains(user)
    json(conn, %{success: true, domains: Enum.map(domains, &serialize_domain/1)})
  end

  def create_domain(conn, params) do
    user = conn.assigns.current_user

    case Mail.create_user_domain(user, params) do
      {:ok, domain} ->
        hostname = Application.get_env(:tempmail, :mail_server_hostname, "mail.tempmailcentral.com")

        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          domain: serialize_domain(domain),
          dns_instructions: Tempmail.Integrations.Postfix.dns_instructions(domain.domain)
        })

      {:error, :system_domain} ->
        conn |> put_status(:conflict) |> json(%{success: false, error: "This is a system domain"})

      {:error, :domain_claimed} ->
        conn |> put_status(:conflict) |> json(%{success: false, error: "Domain already claimed"})

      {:error, :domain_limit} ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Domain limit reached"})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_domain(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Mail.delete_user_domain(user, id) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{success: false, error: "Domain not found"})
      {:error, {:domain_in_use, count}} -> conn |> put_status(:conflict) |> json(%{success: false, error: "Domain has #{count} active mailboxes"})
    end
  end

  def verify_domain(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with %Mail.UserDomain{} = domain <-
           Tempmail.Repo.one(
             from(d in Mail.UserDomain, where: d.user_id == ^user.id and d.id == ^id)
           ),
         {:ok, updated_domain, results} <- Mail.verify_user_domain(domain) do
      json(conn, %{
        success: true,
        domain: serialize_domain(updated_domain),
        verification: results
      })
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
    %{
      id: email.id,
      from: email.from,
      from_name: email.from_name,
      subject: email.subject,
      text: email.text,
      html: email.html,
      received_at: email.received_at,
      read: email.read,
      starred: email.starred,
      archived: email.archived,
      mailbox_id: email.mailbox_id
    }
  end

  defp serialize_mailbox(mailbox) do
    %{
      id: mailbox.id,
      address: mailbox.address,
      prefix: mailbox.prefix,
      domain: mailbox.domain,
      name: mailbox.name,
      is_primary: mailbox.is_primary,
      is_active: mailbox.is_active,
      email_count: length(mailbox.emails || []),
      unread_count: Enum.count(mailbox.emails || [], &(!&1.read))
    }
  end

  defp serialize_domain(domain) do
    %{
      id: domain.id,
      domain: domain.domain,
      is_verified: domain.is_verified,
      is_active: domain.is_active,
      mx_verified: domain.mx_verified,
      spf_verified: domain.spf_verified,
      verification_token: domain.verification_token,
      verified_at: domain.verified_at
    }
  end
end
```

- [ ] **Step 2: Add a helper to Mail context for getting a single user email**

In `lib/tempmail/mail.ex`, add:

```elixir
  def get_user_email(user, id) do
    mailbox_ids = from(m in UserMailbox, where: m.user_id == ^user.id, select: m.id)

    UserEmail
    |> where([e], e.id == ^id and e.mailbox_id in subquery(mailbox_ids))
    |> preload(:mailbox)
    |> Repo.one()
  end
```

- [ ] **Step 3: Add user API routes to the router**

In `lib/tempmail_web/router.ex`, inside the `session_json` API scope (after the email routes), add:

```elixir
    # User API
    get "/user/emails", UserController, :list_emails
    get "/user/emails/:id", UserController, :get_email
    patch "/user/emails/:id", UserController, :update_email
    delete "/user/emails/:id", UserController, :delete_email

    get "/user/mailboxes", UserController, :list_mailboxes
    get "/user/mailboxes/:id", UserController, :get_mailbox
    post "/user/mailboxes", UserController, :create_mailbox
    delete "/user/mailboxes/:id", UserController, :delete_mailbox

    get "/user/domains", UserController, :list_domains
    post "/user/domains", UserController, :create_domain
    delete "/user/domains/:id", UserController, :delete_domain
    post "/user/domains/:id/verify", UserController, :verify_domain
```

- [ ] **Step 4: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles successfully.

- [ ] **Step 5: Commit**

```bash
git add lib/tempmail_web/controllers/api/user_controller.ex lib/tempmail_web/router.ex lib/tempmail/mail.ex
git commit -m "feat: add user email/mailbox/domain CRUD API endpoints"
```

---

## Task 10: Admin API Endpoints (Settings, Users, Blog, Upload, Translate)

**Files:**
- Modify: `lib/tempmail_web/controllers/api/admin_controller.ex`
- Modify: `lib/tempmail_web/router.ex`
- Modify: `config/runtime.exs`

- [ ] **Step 1: Expand AdminController with all missing endpoints**

Replace `lib/tempmail_web/controllers/api/admin_controller.ex` entirely:

```elixir
defmodule TempmailWeb.Api.AdminController do
  use TempmailWeb, :controller

  alias Tempmail.{Accounts, Mail, Content}

  plug :require_admin

  # --- Domains ---

  def domains(conn, _params), do: json(conn, %{success: true, domains: Mail.list_domains()})

  def create_domain(conn, params) do
    case Mail.create_domain(params, conn.assigns.current_user) do
      {:ok, domain} -> json(conn, %{success: true, domain: domain})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def update_domain(conn, %{"id" => id} = params) do
    domain = Mail.get_domain!(id)
    attrs = Map.take(params, ["is_active", "description"])

    case Mail.update_domain(domain, attrs) do
      {:ok, domain} -> json(conn, %{success: true, domain: domain})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_domain(conn, %{"id" => id}) do
    domain = Mail.get_domain!(id)

    case Mail.delete_domain(domain, conn.assigns.current_user) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def set_default_domain(conn, %{"id" => id}) do
    domain = Mail.get_domain!(id)

    case Mail.set_default_domain(domain) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Failed to set default"})
    end
  end

  # --- Users ---

  def users(conn, _params), do: json(conn, %{success: true, users: Accounts.list_users()})

  def ban_user(conn, %{"id" => id} = params) do
    user = Accounts.get_user!(id)
    admin = conn.assigns.current_user

    cond do
      user.id == admin.id ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Cannot ban yourself"})

      Accounts.super_admin?(user) ->
        conn |> put_status(:forbidden) |> json(%{success: false, error: "Cannot ban a super admin"})

      user.banned ->
        Accounts.unban_user(user, admin)
        json(conn, %{success: true, banned: false})

      true ->
        Accounts.ban_user(user, params["reason"], admin)
        json(conn, %{success: true, banned: true})
    end
  end

  def update_role(conn, %{"id" => id, "role" => role}) do
    user = Accounts.get_user!(id)
    admin = conn.assigns.current_user

    cond do
      user.id == admin.id ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Cannot change your own role"})

      not Accounts.super_admin?(admin) ->
        conn |> put_status(:forbidden) |> json(%{success: false, error: "Only super admins can change roles"})

      role == "SUPER_ADMIN" ->
        conn |> put_status(:forbidden) |> json(%{success: false, error: "Cannot assign super admin role"})

      true ->
        case Accounts.update_user_role(user, role, admin) do
          {:ok, _} -> json(conn, %{success: true, role: role})
          {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Invalid role"})
        end
    end
  end

  # --- Settings ---

  def get_settings(conn, _params) do
    settings = Mail.list_settings() |> Enum.map(fn s -> %{key: s.key, value: s.value, type: s.type} end)
    json(conn, %{success: true, settings: settings})
  end

  def update_settings(conn, %{"settings" => settings}) when is_list(settings) do
    Enum.each(settings, fn %{"key" => key, "value" => value} = s ->
      Mail.upsert_setting(key, value, Map.get(s, "type", "string"))
    end)

    Mail.create_audit_log(conn.assigns.current_user, "settings.update", nil, inspect(settings))
    json(conn, %{success: true})
  end

  def update_settings(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{success: false, error: "Expected settings array"})
  end

  def test_mailcow(conn, _params) do
    case Tempmail.Integrations.Mailcow.test_connection() do
      {:ok, _} -> json(conn, %{success: true, connected: true})
      {:error, reason} -> json(conn, %{success: true, connected: false, error: reason})
    end
  end

  # --- Analytics ---

  def analytics(conn, params) do
    days = params |> Map.get("days", "14") |> String.to_integer()
    json(conn, %{success: true, stats: Mail.recent_stats(days)})
  end

  # --- Blog Posts ---

  def list_posts(conn, _params) do
    posts = Content.list_posts()
    json(conn, %{success: true, posts: Enum.map(posts, &serialize_post/1)})
  end

  def get_post(conn, %{"id" => id}) do
    post = Content.get_post!(id)
    json(conn, %{success: true, post: serialize_post(post)})
  end

  def create_post(conn, params) do
    attrs = Map.put(params, "author_id", conn.assigns.current_user.id)

    case Content.upsert_post(attrs) do
      {:ok, post} ->
        Mail.create_audit_log(conn.assigns.current_user, "blog.create", post.slug)
        conn |> put_status(:created) |> json(%{success: true, post: serialize_post(post)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def update_post(conn, %{"id" => id} = params) do
    post = Content.get_post!(id)

    case Content.update_post_with_translations(post, params) do
      {:ok, post} ->
        Mail.create_audit_log(conn.assigns.current_user, "blog.update", post.slug)
        json(conn, %{success: true, post: serialize_post(post)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_post(conn, %{"id" => id}) do
    post = Content.get_post!(id)

    case Content.delete_post(post) do
      {:ok, _} ->
        Mail.create_audit_log(conn.assigns.current_user, "blog.delete", post.slug)
        json(conn, %{success: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Delete failed"})
    end
  end

  # --- Blog Categories ---

  def list_categories(conn, _params) do
    categories = Content.list_categories()
    json(conn, %{success: true, categories: Enum.map(categories, &serialize_category/1)})
  end

  def create_category(conn, params) do
    case Content.create_category(params) do
      {:ok, category} -> conn |> put_status(:created) |> json(%{success: true, category: serialize_category(category)})
      {:error, changeset} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: inspect(changeset.errors)})
    end
  end

  def delete_category(conn, %{"id" => id}) do
    category = Tempmail.Repo.get!(Tempmail.Content.BlogCategory, id)

    case Content.delete_category(category) do
      {:ok, _} -> json(conn, %{success: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{success: false, error: "Delete failed"})
    end
  end

  # --- File Upload ---

  def upload(conn, %{"file" => %Plug.Upload{} = upload}) do
    allowed = ~w(.jpg .jpeg .png .gif .webp)
    ext = Path.extname(upload.filename) |> String.downcase()

    cond do
      ext not in allowed ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "File type not allowed"})

      upload.content_type not in ~w(image/jpeg image/png image/gif image/webp) ->
        conn |> put_status(:bad_request) |> json(%{success: false, error: "Invalid content type"})

      true ->
        upload_dir = Path.join([:code.priv_dir(:tempmail), "static", "uploads"])
        File.mkdir_p!(upload_dir)

        filename = "#{Ecto.UUID.generate()}#{ext}"
        dest = Path.join(upload_dir, filename)
        File.cp!(upload.path, dest)

        json(conn, %{success: true, url: "/uploads/#{filename}"})
    end
  end

  def upload(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{success: false, error: "No file uploaded"})
  end

  # --- Translation (DeepL) ---

  def translate(conn, %{"text" => text, "source_lang" => source, "target_lang" => target}) do
    api_key = Application.get_env(:tempmail, :deepl_api_key, "")

    if api_key == "" do
      conn |> put_status(:service_unavailable) |> json(%{success: false, error: "DeepL API not configured"})
    else
      url = "https://api-free.deepl.com/v2/translate"
      body = Jason.encode!(%{text: [text], source_lang: String.upcase(source), target_lang: map_deepl_lang(target)})
      headers = [{"Authorization", "DeepL-Auth-Key #{api_key}"}, {"Content-Type", "application/json"}]

      case Req.post(url, body: body, headers: headers) do
        {:ok, %{status: 200, body: %{"translations" => [%{"text" => translated} | _]}}} ->
          json(conn, %{success: true, translated_text: translated})

        {:ok, resp} ->
          conn |> put_status(:bad_gateway) |> json(%{success: false, error: "DeepL returned #{resp.status}"})

        {:error, reason} ->
          conn |> put_status(:bad_gateway) |> json(%{success: false, error: inspect(reason)})
      end
    end
  end

  def translate(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{success: false, error: "Missing text, source_lang, or target_lang"})
  end

  # --- Helpers ---

  defp require_admin(conn, _opts) do
    if Accounts.admin?(conn.assigns[:current_user]) do
      conn
    else
      conn |> put_status(:forbidden) |> json(%{success: false, error: "Forbidden"}) |> halt()
    end
  end

  defp map_deepl_lang("pt"), do: "PT-BR"
  defp map_deepl_lang("en"), do: "EN-US"
  defp map_deepl_lang("zh"), do: "ZH-HANS"
  defp map_deepl_lang(lang), do: String.upcase(lang)

  defp serialize_post(post) do
    %{
      id: post.id,
      slug: post.slug,
      status: post.status,
      author_id: post.author_id,
      featured_image: post.featured_image,
      view_count: post.view_count,
      published_at: post.published_at,
      translations: Enum.map(post.translations || [], fn t ->
        %{locale: t.locale, title: t.title, excerpt: t.excerpt, content: t.content, meta_title: t.meta_title, meta_description: t.meta_description}
      end)
    }
  end

  defp serialize_category(cat) do
    %{
      id: cat.id,
      slug: cat.slug,
      is_active: cat.is_active,
      sort_order: cat.sort_order,
      translations: Enum.map(cat.translations || [], fn t ->
        %{locale: t.locale, name: t.name, description: t.description}
      end)
    }
  end
end
```

- [ ] **Step 2: Add deepl_api_key to runtime config**

In `config/runtime.exs`, add to the top-level config block:

```elixir
  deepl_api_key: System.get_env("DEEPL_API_KEY") || ""
```

- [ ] **Step 3: Add all admin routes to the router**

In `lib/tempmail_web/router.ex`, inside the `session_json` API scope, expand admin routes:

```elixir
    # Admin API
    get "/admin/domains", AdminController, :domains
    post "/admin/domains", AdminController, :create_domain
    patch "/admin/domains/:id", AdminController, :update_domain
    delete "/admin/domains/:id", AdminController, :delete_domain
    post "/admin/domains/:id/default", AdminController, :set_default_domain

    get "/admin/users", AdminController, :users
    post "/admin/users/:id/ban", AdminController, :ban_user
    post "/admin/users/:id/role", AdminController, :update_role

    get "/admin/settings", AdminController, :get_settings
    post "/admin/settings", AdminController, :update_settings
    post "/admin/settings/test-mailcow", AdminController, :test_mailcow

    get "/admin/analytics", AdminController, :analytics

    get "/admin/blog/posts", AdminController, :list_posts
    get "/admin/blog/posts/:id", AdminController, :get_post
    post "/admin/blog/posts", AdminController, :create_post
    put "/admin/blog/posts/:id", AdminController, :update_post
    delete "/admin/blog/posts/:id", AdminController, :delete_post

    get "/admin/blog/categories", AdminController, :list_categories
    post "/admin/blog/categories", AdminController, :create_category
    delete "/admin/blog/categories/:id", AdminController, :delete_category

    post "/admin/upload", AdminController, :upload
    post "/admin/translate", AdminController, :translate
```

Remove the old 4 admin routes that are now covered above.

- [ ] **Step 4: Add static paths for uploads**

In `lib/tempmail_web.ex`, find the `static_paths` function and add `"uploads"` to the list.

- [ ] **Step 5: Verify compilation**

Run: `mix compile --warnings-as-errors`

- [ ] **Step 6: Commit**

```bash
git add lib/tempmail_web/controllers/api/admin_controller.ex lib/tempmail_web/router.ex config/runtime.exs lib/tempmail_web.ex
git commit -m "feat: add complete admin API (settings, users, blog, upload, translate)"
```

---

## Task 11: Public Blog API Endpoints

**Files:**
- Create: `lib/tempmail_web/controllers/api/blog_controller.ex`
- Modify: `lib/tempmail_web/router.ex`

- [ ] **Step 1: Create public blog API controller**

```elixir
# lib/tempmail_web/controllers/api/blog_controller.ex
defmodule TempmailWeb.Api.BlogController do
  use TempmailWeb, :controller

  alias Tempmail.Content

  def index(conn, params) do
    locale = params["locale"] || "en"
    posts = Content.list_published_posts(locale)

    json(conn, %{
      success: true,
      posts: Enum.map(posts, fn post ->
        translation = List.first(post.translations)
        %{
          id: post.id,
          slug: post.slug,
          featured_image: post.featured_image,
          published_at: post.published_at,
          view_count: post.view_count,
          title: translation && translation.title,
          excerpt: translation && translation.excerpt
        }
      end)
    })
  end

  def show(conn, %{"slug" => slug} = params) do
    locale = params["locale"] || "en"

    case Content.get_published_post_by_slug(slug, locale) do
      nil ->
        conn |> put_status(:not_found) |> json(%{success: false, error: "Post not found"})

      post ->
        translation = List.first(post.translations)

        json(conn, %{
          success: true,
          post: %{
            id: post.id,
            slug: post.slug,
            featured_image: post.featured_image,
            published_at: post.published_at,
            view_count: post.view_count,
            title: translation && translation.title,
            excerpt: translation && translation.excerpt,
            content: translation && translation.content,
            meta_title: translation && translation.meta_title,
            meta_description: translation && translation.meta_description,
            categories: Enum.map(post.categories, &%{slug: &1.slug})
          }
        })
    end
  end
end
```

- [ ] **Step 2: Add routes**

In `lib/tempmail_web/router.ex`, add to the public API scope:

```elixir
  scope "/api", TempmailWeb.Api do
    pipe_through :api

    get "/blog/posts", BlogController, :index
    get "/blog/posts/:slug", BlogController, :show
  end
```

- [ ] **Step 3: Commit**

```bash
git add lib/tempmail_web/controllers/api/blog_controller.ex lib/tempmail_web/router.ex
git commit -m "feat: add public blog API endpoints"
```

---

## Task 12: SEO - Sitemap Controller

**Files:**
- Create: `lib/tempmail_web/controllers/sitemap_controller.ex`
- Modify: `lib/tempmail_web/router.ex`

- [ ] **Step 1: Create the sitemap controller**

```elixir
# lib/tempmail_web/controllers/sitemap_controller.ex
defmodule TempmailWeb.SitemapController do
  use TempmailWeb, :controller

  alias Tempmail.Content

  @base_url "https://tempmailcentral.com"
  @locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
  @default_locale "en"

  def index(conn, _params) do
    entries = home_entries() ++ blog_listing_entries() ++ blog_post_entries() ++ static_entries()

    xml = render_sitemap(entries)

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(200, xml)
  end

  defp home_entries do
    now = Date.utc_today() |> Date.to_iso8601()

    Enum.map(@locales, fn locale ->
      %{
        url: locale_url(locale, ""),
        lastmod: now,
        changefreq: "daily",
        priority: "1.0",
        alternates: Enum.map(@locales, fn l -> {l, locale_url(l, "")} end)
      }
    end)
  end

  defp blog_listing_entries do
    now = Date.utc_today() |> Date.to_iso8601()

    Enum.map(@locales, fn locale ->
      %{
        url: locale_url(locale, "/blog"),
        lastmod: now,
        changefreq: "daily",
        priority: "0.9",
        alternates: Enum.map(@locales, fn l -> {l, locale_url(l, "/blog")} end)
      }
    end)
  end

  defp blog_post_entries do
    import Ecto.Query
    posts =
      Tempmail.Content.BlogPost
      |> where([p], p.status == "PUBLISHED")
      |> preload(:translations)
      |> Tempmail.Repo.all()

    Enum.flat_map(posts, fn post ->
      post_locales = Enum.map(post.translations, & &1.locale)

      Enum.map(post_locales, fn locale ->
        %{
          url: locale_url(locale, "/blog/#{post.slug}"),
          lastmod: (post.updated_at || post.inserted_at) |> DateTime.to_date() |> Date.to_iso8601(),
          changefreq: "weekly",
          priority: "0.8",
          alternates: Enum.map(post_locales, fn l -> {l, locale_url(l, "/blog/#{post.slug}")} end)
        }
      end)
    end)
  end

  defp static_entries do
    pages = ~w(about privacy terms)
    now = Date.utc_today() |> Date.to_iso8601()

    Enum.flat_map(pages, fn page ->
      Enum.map(@locales, fn locale ->
        %{
          url: locale_url(locale, "/#{page}"),
          lastmod: now,
          changefreq: "monthly",
          priority: "0.5",
          alternates: Enum.map(@locales, fn l -> {l, locale_url(l, "/#{page}")} end)
        }
      end)
    end)
  end

  defp locale_url(@default_locale, path), do: "#{@base_url}#{path}"
  defp locale_url(locale, path), do: "#{@base_url}/#{locale}#{path}"

  defp render_sitemap(entries) do
    urls =
      Enum.map_join(entries, "\n", fn entry ->
        alternates =
          Enum.map_join(entry.alternates || [], "\n    ", fn {lang, href} ->
            ~s(<xhtml:link rel="alternate" hreflang="#{lang}" href="#{href}"/>)
          end)

        """
          <url>
            <loc>#{entry.url}</loc>
            <lastmod>#{entry.lastmod}</lastmod>
            <changefreq>#{entry.changefreq}</changefreq>
            <priority>#{entry.priority}</priority>
            #{alternates}
          </url>
        """
      end)

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
            xmlns:xhtml="http://www.w3.org/1999/xhtml">
    #{urls}
    </urlset>
    """
  end
end
```

- [ ] **Step 2: Add the route**

In `lib/tempmail_web/router.ex`, add at the top of the public scope:

```elixir
  scope "/", TempmailWeb do
    pipe_through :api

    get "/sitemap.xml", SitemapController, :index
    get "/robots.txt", RobotsController, :index
  end
```

- [ ] **Step 3: Commit**

```bash
git add lib/tempmail_web/controllers/sitemap_controller.ex lib/tempmail_web/router.ex
git commit -m "feat: add dynamic sitemap.xml with multi-locale blog URLs"
```

---

## Task 13: SEO - robots.txt Controller

**Files:**
- Create: `lib/tempmail_web/controllers/robots_controller.ex`

- [ ] **Step 1: Create the robots.txt controller**

```elixir
# lib/tempmail_web/controllers/robots_controller.ex
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

    User-agent: Googlebot
    Allow: /
    Disallow: /api/
    Disallow: /admin/
    Disallow: /dashboard/
    Disallow: /auth/
    Disallow: /users/

    Sitemap: #{@base_url}/sitemap.xml
    Host: #{@base_url}
    """

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, robots)
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add lib/tempmail_web/controllers/robots_controller.ex
git commit -m "feat: add robots.txt controller"
```

---

## Task 14: SEO - Structured Data (Schema.org JSON-LD)

**Files:**
- Create: `lib/tempmail_web/components/seo_components.ex`
- Modify: `lib/tempmail_web/components/layouts/root.html.heex`

- [ ] **Step 1: Create the SEO component module**

```elixir
# lib/tempmail_web/components/seo_components.ex
defmodule TempmailWeb.SEOComponents do
  use Phoenix.Component

  @base_url "https://tempmailcentral.com"

  attr :page, :atom, default: :home

  def structured_data(assigns) do
    ~H"""
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(website_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(webapp_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(organization_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(howto_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(faq_schema())) %>
    </script>
    """
  end

  defp website_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "TempMailCentral",
      "alternateName" => ["Temp Mail", "TempMail", "Temporary Email"],
      "url" => @base_url,
      "description" => "Free disposable temporary email service. Get instant temp mail addresses for signups, verifications, and privacy protection.",
      "potentialAction" => %{
        "@type" => "SearchAction",
        "target" => %{"@type" => "EntryPoint", "urlTemplate" => "#{@base_url}/?q={search_term_string}"},
        "query-input" => "required name=search_term_string"
      },
      "inLanguage" => ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
    }
  end

  defp webapp_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebApplication",
      "name" => "Temp Mail - Disposable Temporary Email",
      "alternateName" => "TempMailCentral",
      "url" => @base_url,
      "description" => "Free temporary email generator. Create disposable email addresses instantly without registration.",
      "applicationCategory" => "UtilitiesApplication",
      "operatingSystem" => "Any",
      "browserRequirements" => "Requires JavaScript",
      "offers" => %{"@type" => "Offer", "price" => "0", "priceCurrency" => "USD"},
      "featureList" => [
        "Instant email generation", "No registration required", "Auto-delete after 10 minutes",
        "Real-time email receiving", "Multiple domain support", "Extend email lifetime",
        "Save as permanent mailbox", "20+ languages supported"
      ],
      "aggregateRating" => %{
        "@type" => "AggregateRating", "ratingValue" => "4.8",
        "ratingCount" => "12847", "bestRating" => "5", "worstRating" => "1"
      }
    }
  end

  defp organization_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "TempMailCentral",
      "url" => @base_url,
      "logo" => "#{@base_url}/logo.png",
      "contactPoint" => %{
        "@type" => "ContactPoint",
        "contactType" => "customer service",
        "availableLanguage" => ~w(English Spanish French German Portuguese Chinese Japanese Arabic Russian Hindi)
      }
    }
  end

  defp howto_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "HowTo",
      "name" => "How to Use Temp Mail - Disposable Temporary Email",
      "description" => "Learn how to get and use a free temporary email address in 3 simple steps.",
      "totalTime" => "PT1M",
      "step" => [
        %{"@type" => "HowToStep", "name" => "Get Instant Email", "text" => "Visit TempMailCentral and a temporary email address is automatically generated for you.", "position" => 1},
        %{"@type" => "HowToStep", "name" => "Use It Anywhere", "text" => "Copy your temporary email address and use it for website signups, verifications, or any service requiring an email.", "position" => 2},
        %{"@type" => "HowToStep", "name" => "Receive & Auto-Delete", "text" => "Emails sent to your temp mail appear instantly. After 10 minutes, everything is automatically deleted for your privacy.", "position" => 3}
      ]
    }
  end

  defp faq_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => [
        faq("What is a temporary email or temp mail?", "A temporary email (also called temp mail, disposable email, or throwaway email) is a self-destructing email address that you can use for a short period. It helps protect your real email from spam, phishing, and unwanted marketing emails."),
        faq("How does disposable email work?", "Disposable email works by providing you with a random email address instantly. Any emails sent to this address appear in your temporary inbox in real-time. After a set period (typically 10 minutes), the email address and all received messages are automatically deleted."),
        faq("Is temp mail safe to use?", "Yes, temp mail is safe to use for non-sensitive purposes like signing up for websites, downloading resources, or testing applications."),
        faq("How long does a temporary email last?", "By default, temporary email addresses on TempMailCentral last for 10 minutes. Logged-in users can extend the time up to 30 days or save the address as a permanent mailbox."),
        faq("Can websites detect temp mail?", "Some websites maintain blocklists of known temporary email domains. TempMailCentral uses multiple domains to minimize this."),
        faq("Do I need to register to use temp mail?", "No registration is required. Simply visit the website and you will automatically receive a temporary email address."),
        faq("Can I receive attachments with temp mail?", "Yes, TempMailCentral supports receiving email attachments."),
        faq("What is temp mail used for?", "Temp mail is commonly used for signing up for free trials, avoiding spam from newsletters, testing email functionality, protecting your real email from data breaches, and online shopping on untrusted sites.")
      ]
    }
  end

  defp faq(question, answer) do
    %{"@type" => "Question", "name" => question, "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}}
  end
end
```

- [ ] **Step 2: Add structured data and meta tags to the root layout**

Read `lib/tempmail_web/components/layouts/root.html.heex` and add inside `<head>`:

```heex
    <TempmailWeb.SEOComponents.structured_data page={assigns[:seo_page] || :other} />

    <!-- Dynamic meta tags -->
    <meta :if={assigns[:meta_description]} name="description" content={assigns[:meta_description]} />
    <link :if={assigns[:canonical_url]} rel="canonical" href={assigns[:canonical_url]} />

    <!-- OpenGraph -->
    <meta :if={assigns[:og_title]} property="og:title" content={assigns[:og_title]} />
    <meta :if={assigns[:og_description]} property="og:description" content={assigns[:og_description]} />
    <meta :if={assigns[:og_url]} property="og:url" content={assigns[:og_url]} />
    <meta property="og:type" content={assigns[:og_type] || "website"} />
    <meta property="og:site_name" content="TempMailCentral" />

    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta :if={assigns[:og_title]} name="twitter:title" content={assigns[:og_title]} />
    <meta :if={assigns[:og_description]} name="twitter:description" content={assigns[:og_description]} />
```

- [ ] **Step 3: Add SEO assigns to HomeLive mount**

In `lib/tempmail_web/live/home_live.ex`, in the `mount` function, add assigns:

```elixir
    |> assign(:seo_page, :home)
    |> assign(:meta_description, "Free disposable temporary email service. Get instant temp mail addresses for signups, verifications, and privacy protection.")
    |> assign(:og_title, "TempMailCentral - Free Temporary Email")
    |> assign(:og_description, "Free disposable temporary email service. Get instant temp mail addresses for signups, verifications, and privacy protection.")
    |> assign(:og_url, "https://tempmailcentral.com")
    |> assign(:canonical_url, "https://tempmailcentral.com")
```

- [ ] **Step 4: Commit**

```bash
git add lib/tempmail_web/components/seo_components.ex lib/tempmail_web/components/layouts/root.html.heex lib/tempmail_web/live/home_live.ex
git commit -m "feat: add Schema.org structured data and dynamic OG/meta tags"
```

---

## Task 15: i18n - Gettext Translation Files

**Files:**
- Create: `priv/gettext/en/LC_MESSAGES/default.po` (and 19 more locales)
- Modify: `lib/tempmail_web/i18n.ex`

- [ ] **Step 1: Generate Gettext .pot and .po files**

Run: `mix gettext.extract`

Then for each locale, create directories and seed .po files:

```bash
mkdir -p priv/gettext/es/LC_MESSAGES
mkdir -p priv/gettext/fr/LC_MESSAGES
mkdir -p priv/gettext/de/LC_MESSAGES
mkdir -p priv/gettext/pt/LC_MESSAGES
mkdir -p priv/gettext/zh/LC_MESSAGES
mkdir -p priv/gettext/ja/LC_MESSAGES
mkdir -p priv/gettext/ar/LC_MESSAGES
mkdir -p priv/gettext/ru/LC_MESSAGES
mkdir -p priv/gettext/hi/LC_MESSAGES
mkdir -p priv/gettext/ko/LC_MESSAGES
mkdir -p priv/gettext/it/LC_MESSAGES
mkdir -p priv/gettext/nl/LC_MESSAGES
mkdir -p priv/gettext/tr/LC_MESSAGES
mkdir -p priv/gettext/pl/LC_MESSAGES
mkdir -p priv/gettext/vi/LC_MESSAGES
mkdir -p priv/gettext/th/LC_MESSAGES
mkdir -p priv/gettext/id/LC_MESSAGES
mkdir -p priv/gettext/sv/LC_MESSAGES
mkdir -p priv/gettext/el/LC_MESSAGES
```

- [ ] **Step 2: Create English default.po with core UI strings**

Create `priv/gettext/en/LC_MESSAGES/default.po` with the key UI strings ported from the Next.js `messages/en.json`. Include strings for: nav items, home page hero text, feature descriptions, FAQ content, footer, auth forms, dashboard labels.

Each msgid/msgstr pair in the .po file should contain the English text. For non-English locales, the msgstr will contain the translated version (initially blank — can be filled via the DeepL translate API endpoint we just created).

- [ ] **Step 3: Configure supported locales in Gettext**

In `config/config.exs`, add:

```elixir
config :tempmail, TempmailWeb.Gettext,
  default_locale: "en",
  locales: ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
```

- [ ] **Step 4: Commit**

```bash
git add priv/gettext/ config/config.exs
git commit -m "feat: set up Gettext with 20 locales and core English translations"
```

---

## Task 16: i18n - Locale Routing in LiveViews

**Files:**
- Modify: `lib/tempmail_web/router.ex` (already has `/:locale` scope)
- Modify: `lib/tempmail_web/i18n.ex`

- [ ] **Step 1: Update the i18n module to set Gettext locale from params**

Replace `lib/tempmail_web/i18n.ex`:

```elixir
defmodule TempmailWeb.I18n do
  @supported_locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
  @default_locale "en"

  def supported_locales, do: @supported_locales
  def default_locale, do: @default_locale

  def set_locale(locale) when locale in @supported_locales do
    Gettext.put_locale(TempmailWeb.Gettext, locale)
    locale
  end

  def set_locale(_), do: set_locale(@default_locale)

  def translate(locale, key, fallback \\ nil) do
    Gettext.put_locale(TempmailWeb.Gettext, locale)
    result = Gettext.dgettext(TempmailWeb.Gettext, "default", key)
    if result == key, do: fallback || key, else: result
  end
end
```

- [ ] **Step 2: Set locale in LiveView mounts from `:locale` param**

In each LiveView that handles the `/:locale` scope, add at the start of `mount`:

```elixir
    locale = params["locale"] || "en"
    TempmailWeb.I18n.set_locale(locale)
    socket = assign(socket, :locale, locale)
```

This is already partially handled by the localized routes in the router. The key LiveViews to update: `HomeLive`, `StaticPageLive`, `BlogLive`, `BlogPostLive`.

- [ ] **Step 3: Commit**

```bash
git add lib/tempmail_web/i18n.ex lib/tempmail_web/live/home_live.ex lib/tempmail_web/live/static_page_live.ex lib/tempmail_web/live/blog_live.ex lib/tempmail_web/live/blog_post_live.ex
git commit -m "feat: wire up Gettext locale routing in LiveViews"
```

---

## Final Verification

- [ ] **Step 1: Run full compilation**

Run: `mix compile --warnings-as-errors`

- [ ] **Step 2: Run migrations**

Run: `mix ecto.migrate`

- [ ] **Step 3: Start the server and smoke test**

Run: `mix phx.server`

Test:
- Visit `http://localhost:4001` — home page loads
- Visit `http://localhost:4001/sitemap.xml` — sitemap renders
- Visit `http://localhost:4001/robots.txt` — robots.txt renders
- Visit `http://localhost:4001/admin` — redirects non-admin users
- POST to `/api/webhook/mailcow` without signature header — returns 401
- POST to `/api/email/generate` — rate limited after 10 requests/min
