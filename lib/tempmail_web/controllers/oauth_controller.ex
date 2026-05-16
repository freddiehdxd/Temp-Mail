defmodule TempmailWeb.OAuthController do
  use TempmailWeb, :controller

  alias Tempmail.Accounts
  alias TempmailWeb.UserAuth

  @providers %{
    "google" => %{
      authorize_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      user_url: "https://www.googleapis.com/oauth2/v3/userinfo",
      scope: "openid email profile",
      client_id_env: "GOOGLE_CLIENT_ID",
      client_secret_env: "GOOGLE_CLIENT_SECRET"
    },
    "discord" => %{
      authorize_url: "https://discord.com/api/oauth2/authorize",
      token_url: "https://discord.com/api/oauth2/token",
      user_url: "https://discord.com/api/users/@me",
      scope: "identify email",
      client_id_env: "DISCORD_CLIENT_ID",
      client_secret_env: "DISCORD_CLIENT_SECRET"
    }
  }

  def request(conn, %{"provider" => provider}) do
    with {:ok, config} <- provider_config(provider),
         {:ok, client_id} <- fetch_env(config.client_id_env),
         {:ok, _client_secret} <- fetch_env(config.client_secret_env) do
      state = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)

      params = %{
        client_id: client_id,
        redirect_uri: callback_url(conn, provider),
        response_type: "code",
        scope: config.scope,
        state: state,
        access_type: "offline",
        prompt: "select_account"
      }

      conn
      |> put_session(:oauth_state, state)
      |> put_session(:oauth_return_to, Map.get(conn.params, "return_to", "/"))
      |> redirect(external: config.authorize_url <> "?" <> URI.encode_query(params))
    else
      _ ->
        conn
        |> put_flash(:error, "OAuth provider is not configured.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def signin_alias(conn, _params) do
    redirect(conn, to: ~p"/users/log_in")
  end

  def callback(conn, %{"provider" => provider, "code" => code, "state" => state}) do
    with true <- state == get_session(conn, :oauth_state),
         {:ok, config} <- provider_config(provider),
         {:ok, token} <- exchange_code(conn, provider, config, code),
         {:ok, profile} <- fetch_profile(config, token),
         {:ok, attrs} <- normalize_profile(provider, profile),
         {:ok, user} <- Accounts.get_or_register_oauth_user(attrs) do
      conn
      |> delete_session(:oauth_state)
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, %{"remember_me" => "true"})
    else
      _ ->
        conn
        |> delete_session(:oauth_state)
        |> put_flash(:error, "Unable to sign in with #{String.capitalize(provider)}.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def callback(conn, %{"provider" => provider}) do
    conn
    |> put_flash(:error, "Unable to sign in with #{String.capitalize(provider)}.")
    |> redirect(to: ~p"/users/log_in")
  end

  defp provider_config(provider) do
    case Map.fetch(@providers, provider) do
      {:ok, config} -> {:ok, config}
      :error -> {:error, :unknown_provider}
    end
  end

  defp fetch_env(name) do
    if Application.get_env(:tempmail, :load_dotenv, false) do
      load_dotenv()
    end

    case System.get_env(name) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :missing_env}
    end
  end

  defp load_dotenv do
    [
      Path.expand("../../../.env", __DIR__),
      Path.expand(".env", File.cwd!())
    ]
    |> Enum.uniq()
    |> Enum.find(&File.exists?/1)
    |> case do
      nil ->
        :ok

      path ->
        path
        |> File.read!()
        |> String.split(~r/\R/, trim: true)
        |> Enum.each(fn raw_line ->
          line = String.trim(raw_line)

          if line != "" and not String.starts_with?(line, "#") and String.contains?(line, "=") do
            [key, value] = String.split(line, "=", parts: 2)
            key = String.trim(key)

            value =
              value
              |> String.trim()
              |> String.trim_leading("\"")
              |> String.trim_trailing("\"")
              |> String.trim_leading("'")
              |> String.trim_trailing("'")

            if key != "" and System.get_env(key) in [nil, ""] do
              System.put_env(key, value)
            end
          end
        end)
    end
  end

  defp exchange_code(conn, provider, config, code) do
    with {:ok, client_id} <- fetch_env(config.client_id_env),
         {:ok, client_secret} <- fetch_env(config.client_secret_env),
         {:ok, response} <-
           Req.post(config.token_url,
             form: %{
               client_id: client_id,
               client_secret: client_secret,
               code: code,
               grant_type: "authorization_code",
               redirect_uri: callback_url(conn, provider)
             },
             headers: [{"accept", "application/json"}]
           ),
         %{"access_token" => token} <- response.body do
      {:ok, token}
    else
      _ -> {:error, :token_exchange_failed}
    end
  end

  defp fetch_profile(config, token) do
    case Req.get(config.user_url, headers: [{"authorization", "Bearer #{token}"}]) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      _ -> {:error, :profile_fetch_failed}
    end
  end

  defp normalize_profile("google", %{"email" => email} = profile) when is_binary(email) do
    {:ok,
     %{
       email: email,
       name: profile["name"],
       image: profile["picture"]
     }}
  end

  defp normalize_profile("discord", %{"email" => email} = profile) when is_binary(email) do
    avatar =
      if profile["avatar"] && profile["id"] do
        "https://cdn.discordapp.com/avatars/#{profile["id"]}/#{profile["avatar"]}.png"
      end

    {:ok,
     %{
       email: email,
       name: profile["global_name"] || profile["username"],
       image: avatar
     }}
  end

  defp normalize_profile(_, _), do: {:error, :missing_email}

  defp callback_url(conn, provider), do: url(conn, ~p"/auth/#{provider}/callback")
end
