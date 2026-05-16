defmodule TempmailWeb.AuthErrorLive do
  use TempmailWeb, :live_view

  @messages %{
    "Configuration" => "There is a problem with the server configuration.",
    "AccessDenied" =>
      "Access denied. You may not have permission to sign in or your account may be banned.",
    "Verification" => "The verification token has expired or has already been used.",
    "OAuthSignin" => "Error starting the OAuth sign in process.",
    "OAuthCallback" => "Error handling the response from the OAuth provider.",
    "OAuthCreateAccount" => "Could not create an OAuth account.",
    "EmailCreateAccount" => "Could not create an email account.",
    "Callback" => "Error in the OAuth callback handler.",
    "OAuthAccountNotLinked" => "This email is already associated with another account.",
    "SessionRequired" => "Please sign in to access this page."
  }

  @impl true
  def mount(params, _session, socket) do
    code = Map.get(params, "error")

    {:ok,
     socket
     |> assign(:page_title, "Authentication Error")
     |> assign(:current_user, nil)
     |> assign(:locale, "en")
     |> assign(:error_code, code)
     |> assign(
       :message,
       Map.get(@messages, code, "An unexpected error occurred during authentication.")
     )}
  end
end
