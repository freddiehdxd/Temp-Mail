defmodule Tempmail.EmailVerifier.MailSift do
  @moduledoc """
  MailSift-backed email verification.
  """

  require Logger

  @endpoint "https://mailsift.dev/api/v1/verify"

  def verify_email(email) when is_binary(email) do
    case Req.get(@endpoint, params: [email: email], headers: headers(), receive_timeout: 5_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, %{disposable?: disposable?(body)}}

      {:ok, %{status: status}} ->
        Logger.warning("MailSift verification failed with HTTP #{status}")
        {:error, :unavailable}

      {:error, reason} ->
        Logger.warning("MailSift verification request failed: #{inspect(reason)}")
        {:error, :unavailable}
    end
  end

  defp headers do
    case Application.get_env(:tempmail, :mail_sift_api_key) do
      key when is_binary(key) and key != "" -> [{"x-api-key", key}]
      _ -> []
    end
  end

  defp disposable?(%{"checks" => %{"disposable" => true}}), do: true
  defp disposable?(%{"is_disposable" => true}), do: true
  defp disposable?(%{"disposable" => true}), do: true
  defp disposable?(_), do: false
end
