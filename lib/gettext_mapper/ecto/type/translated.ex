defmodule GettextMapper.Ecto.Type.Translated do
  @moduledoc """
  Ecto.Type to store translations in a map with localized strings.

  Provides casting, loading, dumping, and helper functions to fetch
  translations according to the configured Gettext backend.
  """

  use Ecto.Type

  @doc """
  Specifies the underlying database type.
  """
  def type, do: :map

  @doc """
  Casts a map of translations.

  Keys must be in the list of supported locales defined by the configured
  Gettext backend.
  """
  def cast(params) when is_map(params) do
    if Enum.all?(Map.keys(params), &(&1 in supported_locales())) do
      {:ok, params}
    else
      :error
    end
  end

  def cast(_), do: :error

  @doc """
  Loads a value from the database.
  """
  def load(params) when is_map(params), do: {:ok, params}
  def load(_), do: :error

  @doc """
  Dumps a value to the database.
  """
  def dump(value) when is_map(value), do: {:ok, value}
  def dump(_), do: :error

  @doc """
  Gets the localized string from the translations map for the current locale.

  Falls back to the default locale, then to the given default value.
  """
  def localize(nil, _default \\ ""), do: ""

  def localize(value, default) when is_map(value) do
    value[locale()] || value[default_locale()] || default
  end

  @doc """
  Fetches the translation for the given locale.

  Falls back to the default locale, then returns "NO TRANSLATION" if
  none are found.
  """
  def translate(values, locale) when is_map(values) do
    cond do
      str = Map.get(values, locale) ->
        str

      str = Map.get(values, default_locale()) ->
        str

      true ->
        "NO TRANSLATION"
    end
  end

  defp gettext_module do
    Application.get_env(:gettext_mapper, :gettext) ||
      raise """
      :gettext_mapper expects a :gettext configuration.
      Please add `config :gettext_mapper, gettext: MyApp.Gettext` to your config.
      """
  end

  defp supported_locales do
    gettext_module().known_locales()
  end

  defp locale do
    gettext_module().get_locale()
  end

  defp default_locale do
    gettext_module().default_locale()
  end
end
