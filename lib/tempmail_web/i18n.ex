defmodule TempmailWeb.I18n do
  @supported_locales ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
  @default_locale "en"

  def supported_locales, do: @supported_locales
  def default_locale, do: @default_locale

  def set_locale(locale) when locale in @supported_locales do
    Gettext.put_locale(TempmailWeb.Gettext, locale)
    locale
  end

  def set_locale(_), do: set_locale(@default_locale)
end
