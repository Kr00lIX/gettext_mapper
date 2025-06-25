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
end
