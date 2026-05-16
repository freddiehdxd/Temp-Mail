defmodule Tempmail.EmailVerifier do
  @moduledoc """
  Resolves the configured email verification adapter.
  """

  def verify_email(email) do
    verifier().verify_email(email)
  end

  defp verifier do
    Application.get_env(:tempmail, :email_verifier, Tempmail.EmailVerifier.MailSift)
  end
end
