defmodule Tempmail.Integrations.Mailcow do
  @moduledoc """
  Minimal Mailcow API client matching the Next.js integration.
  """

  def configured? do
    api_url() != "" and api_key() != ""
  end

  def get_domains, do: request(:get, "/get/domain/all")

  def add_domain(domain) do
    request(:post, "/add/domain", %{
      domain: domain,
      description: "TempMail Domain",
      aliases: 400,
      mailboxes: 10,
      defquota: 1024,
      maxquota: 2048,
      quota: 10240,
      active: 1,
      restart_sogo: 0
    })
  end

  def delete_domain(domain), do: request(:post, "/delete/domain", [domain])

  def get_mailboxes(nil), do: request(:get, "/get/mailbox/all")
  def get_mailboxes(domain), do: request(:get, "/get/mailbox/#{domain}")

  def create_catch_all_mailbox(domain) do
    password = secure_password()

    request(:post, "/add/mailbox", %{
      local_part: "catchall",
      domain: domain,
      name: "Catch-All",
      quota: 1024,
      password: password,
      password2: password,
      active: 1
    })
  end

  def setup_catch_all(domain) do
    request(:post, "/add/alias", %{
      address: "@#{domain}",
      goto: "catchall@#{domain}",
      active: 1
    })
  end

  def test_connection(url, key) do
    Req.get("#{String.trim_trailing(url, "/")}/api/v1/get/domain/all",
      headers: [{"x-api-key", key}]
    )
  end

  defp request(method, endpoint, body \\ nil) do
    if configured?() do
      opts = [
        headers: [{"content-type", "application/json"}, {"x-api-key", api_key()}],
        json: body
      ]

      case Req.request(
             [method: method, url: "#{api_url()}/api/v1#{endpoint}"] ++
               Enum.reject(opts, fn {_, v} -> is_nil(v) end)
           ) do
        {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, {status, body}}
        error -> error
      end
    else
      {:error, :not_configured}
    end
  end

  defp api_url,
    do: Application.get_env(:tempmail, :mailcow_api_url, "") |> String.trim_trailing("/")

  defp api_key, do: Application.get_env(:tempmail, :mailcow_api_key, "")

  defp secure_password do
    alphabet = ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"

    for _ <- 1..32, into: "" do
      <<Enum.random(alphabet)>>
    end
  end
end
