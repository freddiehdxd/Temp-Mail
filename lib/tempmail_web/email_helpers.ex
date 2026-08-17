defmodule TempmailWeb.EmailHelpers do
  @moduledoc """
  Helpers for displaying received email content.

  Senders often include an empty `text/plain` part alongside the real HTML
  body, so blank strings must be treated the same as missing parts. HTML
  bodies are rendered inside a sandboxed iframe (see `email_srcdoc/1`) so
  attacker-controlled markup can't run scripts in the app's origin.
  """

  @doc "Returns the value, or nil when it is nil or blank."
  def presence(nil), do: nil

  def presence(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  @doc "True when the email has a non-blank HTML body."
  def email_html?(email), do: presence(email["html"]) != nil

  @doc """
  HTML document for the viewer iframe's `srcdoc`.

  The `<base target>` makes links open in a new tab, which is the only kind
  of navigation the iframe's sandbox (`allow-popups`) permits.
  """
  def email_srcdoc(email) do
    ~s(<base target="_blank">) <> (email["html"] || "")
  end

  @doc "Plain-text snippet for inbox list rows."
  def email_preview(email) do
    (presence(email["text"]) || strip_tags(email["html"] || ""))
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.slice(0, 100)
  end

  defp strip_tags(html) do
    html
    |> String.replace(~r/<(script|style|title)[^>]*>.*?<\/\1>/is, " ")
    |> String.replace(~r/<[^>]*>/, " ")
  end
end
