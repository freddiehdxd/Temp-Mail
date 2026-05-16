defmodule Tempmail.EmailVerifier.AllowAll do
  @moduledoc false

  def verify_email(_email), do: {:ok, %{disposable?: false}}
end
