defmodule Tempmail.EmailVerifier.BlockAll do
  @moduledoc false

  def verify_email(_email), do: {:ok, %{disposable?: true}}
end
