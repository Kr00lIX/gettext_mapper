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
  Gettext backend. Values must be strings or nil.
  """
  def cast(params) when is_map(params) do
    supported = supported_locales()

    # If no locales are configured, accept any reasonable locale strings
    valid_keys =
      if Enum.empty?(supported) do
        Enum.all?(Map.keys(params), &is_binary/1)
      else
        Enum.all?(Map.keys(params), &(&1 in supported))
      end

    valid_values = Enum.all?(Map.values(params), &(is_binary(&1) or is_nil(&1)))

    if valid_keys and valid_values do
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
  def load(nil), do: {:ok, nil}
  def load(_), do: :error

  @doc """
  Dumps a value to the database.
  """
  def dump(value) when is_map(value), do: {:ok, value}
  def dump(_), do: :error

  defp supported_locales do
    GettextMapper.GettextAPI.known_locales()
  end
end
