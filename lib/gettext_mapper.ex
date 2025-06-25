defmodule GettextMapper do
  @moduledoc """
  Provides helper functions to fetch localized strings from translation maps.
  """

  @doc """
  Returns the localized string from a translations map for the current locale.

  Falls back to the default locale, then to the given default value.
  """
  @spec localize(map() | nil, String.t()) :: String.t()
  def localize(value, _default \\ "")

  def localize(nil, _default), do: ""

  def localize(value, default) when is_map(value) do
    value[locale()] || value[default_locale()] || default
  end

  @doc """
  Fetches the translation for the specified locale from a translations map.

  Falls back to the default locale, then to the configured default translation
  message if none is found.
  The default message can be set via the `:default_translation` config
  (defaults to "NO TRANSLATION").
  """
  @spec translate(map(), String.t()) :: String.t()
  def translate(values, locale) when is_map(values) do
    cond do
      str = Map.get(values, locale) -> str
      str = Map.get(values, default_locale()) -> str
      true -> default_translation()
    end
  end

  defp gettext_module do
    Application.get_env(:gettext_mapper, :gettext) ||
      raise(
        "gettext_mapper expects :gettext in config, e.g. config :gettext_mapper, gettext: MyApp.Gettext"
      )
  end

  defp locale, do: gettext_module().get_locale()

  defp default_locale, do: gettext_module().default_locale()

  # Retrieves the default translation message from config, defaulting to "NO TRANSLATION".
  defp default_translation do
    Application.get_env(:gettext_mapper, :default_translation, "NO TRANSLATION")
  end
end
