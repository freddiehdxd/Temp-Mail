defmodule TempmailWeb.I18n do
  @moduledoc false

  @default_locale "en"

  def t(locale, path, default) do
    locale
    |> load_messages()
    |> get_in(String.split(path, "."))
    |> case do
      value when is_binary(value) -> value
      _ -> fallback(path, default)
    end
  end

  defp fallback(path, default) do
    @default_locale
    |> load_messages()
    |> get_in(String.split(path, "."))
    |> case do
      value when is_binary(value) -> value
      _ -> default
    end
  end

  defp load_messages(locale) do
    locale = locale || @default_locale

    locale
    |> messages_path()
    |> File.read()
    |> case do
      {:ok, json} -> Jason.decode!(json)
      _ -> %{}
    end
  end

  defp messages_path(locale) do
    Path.expand(Path.join(["..", "messages", "#{locale}.json"]), File.cwd!())
  end
end
