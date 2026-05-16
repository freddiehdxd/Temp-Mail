defmodule TempmailWeb.I18n do
  @supported_locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
  @default_locale "en"

  @messages @supported_locales
            |> Map.new(fn locale ->
              path = Path.join(:code.priv_dir(:tempmail), "messages/#{locale}.json")

              data =
                if File.exists?(path) do
                  path |> File.read!() |> Jason.decode!()
                else
                  %{}
                end

              {locale, data}
            end)

  def supported_locales, do: @supported_locales
  def default_locale, do: @default_locale

  def set_locale(locale) when locale in @supported_locales do
    Gettext.put_locale(TempmailWeb.Gettext, locale)
    locale
  end

  def set_locale(_), do: set_locale(@default_locale)

  def t(locale, key, fallback \\ nil) do
    result = get_nested(@messages[locale] || %{}, String.split(key, "."))

    cond do
      is_binary(result) -> result
      fallback != nil -> fallback
      true -> get_nested(@messages[@default_locale] || %{}, String.split(key, ".")) || key
    end
  end

  defp get_nested(map, []), do: map
  defp get_nested(map, [head | tail]) when is_map(map), do: get_nested(Map.get(map, head), tail)
  defp get_nested(_, _), do: nil
end
