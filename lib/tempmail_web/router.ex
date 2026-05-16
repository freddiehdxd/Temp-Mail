defmodule TempmailWeb.Router do
  use TempmailWeb, :router

  import TempmailWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TempmailWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :session_json do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_user
  end

  scope "/", TempmailWeb do
    pipe_through :browser

    live_session :public, on_mount: [{TempmailWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive, :index
      live "/about", StaticPageLive, :about
      live "/privacy", StaticPageLive, :privacy
      live "/terms", StaticPageLive, :terms
      live "/blog", BlogLive, :index
      live "/blog/:slug", BlogPostLive, :show
    end
  end

  scope "/api", TempmailWeb.Api do
    pipe_through :api

    post "/webhook/mailcow", WebhookController, :mailcow
    put "/webhook/mailcow", WebhookController, :mailcow
  end

  scope "/api", TempmailWeb.Api do
    pipe_through :session_json

    post "/email/generate", EmailController, :generate
    get "/email/inbox", EmailController, :inbox
    post "/email/refresh", EmailController, :refresh
    post "/email/read", EmailController, :mark_read
    delete "/email/delete", EmailController, :delete
    post "/email/extend", EmailController, :extend

    get "/admin/domains", AdminController, :domains
    post "/admin/domains", AdminController, :create_domain
    get "/admin/users", AdminController, :users
    get "/admin/analytics", AdminController, :analytics
  end

  # Other scopes may use custom stacks.
  # scope "/api", TempmailWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tempmail, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TempmailWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TempmailWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{TempmailWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

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

  scope "/", TempmailWeb do
    pipe_through [:browser]

    get "/auth/signin", OAuthController, :signin_alias
    live "/auth/error", AuthErrorLive, :show
    get "/auth/:provider", OAuthController, :request
    get "/auth/:provider/callback", OAuthController, :callback
    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{TempmailWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/:locale", TempmailWeb do
    pipe_through :browser

    live_session :localized_public, on_mount: [{TempmailWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive, :index
      live "/about", StaticPageLive, :about
      live "/privacy", StaticPageLive, :privacy
      live "/terms", StaticPageLive, :terms
      live "/blog", BlogLive, :index
      live "/blog/:slug", BlogPostLive, :show
    end
  end

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
end
