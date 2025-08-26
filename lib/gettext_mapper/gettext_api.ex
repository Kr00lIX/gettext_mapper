defmodule GettextMapper.GettextAPI do
  @moduledoc """
  Provides a unified API for interacting with the configured Gettext backend.

  This module abstracts Gettext backend operations and provides easy access to
  locale information and configuration. All functions delegate to the configured
  Gettext backend.

  ## Configuration

  Configure your Gettext backend in your application configuration:

      config :gettext_mapper,
        gettext: MyApp.Gettext,
        supported_locales: ["en", "de", "es", "fr"]
  """

  @doc """
  Returns the current locale for the configured Gettext backend.

  ## Examples

      iex> GettextMapper.GettextAPI.locale()
      "en"

      iex> Gettext.put_locale(MyApp.Gettext, "de")
      iex> GettextMapper.GettextAPI.locale()
      "de"
  """
  @spec locale() :: String.t()
  def locale do
    Gettext.get_locale(gettext_module())
  end

  @doc """
  Returns all known locales for the configured Gettext backend.

  First checks for configured supported_locales, then falls back to
  locales discovered from .po files in the priv/gettext directory.

  ## Examples

      iex> GettextMapper.GettextAPI.known_locales()
      ["en", "de", "es", "fr"]

  ## Configuration

  You can explicitly configure supported locales:

      config :gettext_mapper,
        gettext: MyApp.Gettext,
        supported_locales: ["en", "de", "es", "fr"]
  """
  @spec known_locales() :: [String.t()]
  def known_locales do
    case Application.get_env(:gettext_mapper, :supported_locales) do
      nil ->
        Gettext.known_locales(gettext_module())

      locales when is_list(locales) ->
        locales

      _ ->
        Gettext.known_locales(gettext_module())
    end
  end

  @doc """
  Returns the default locale for the configured Gettext backend.

  This is the locale that will be used as a fallback when a translation
  is not available in the current locale.

  ## Examples

      iex> GettextMapper.GettextAPI.default_locale()
      "en"
  """
  @spec default_locale() :: String.t()
  def default_locale do
    gettext_module().__gettext__(:default_locale)
  end

  @doc """
  Returns the default domain for the configured Gettext backend.

  This is the domain that will be used when no domain is explicitly specified.

  ## Examples

      iex> GettextMapper.GettextAPI.default_domain()
      "default"
  """
  @spec default_domain() :: String.t()
  def default_domain do
    gettext_module().__gettext__(:default_domain)
  end

  @doc """
  Returns the configured Gettext backend module.

  Raises an error if no backend is configured.

  ## Examples

      iex> GettextMapper.GettextAPI.gettext_module()
      MyApp.Gettext

  ## Configuration

      config :gettext_mapper,
        gettext: MyApp.Gettext
  """
  @spec gettext_module() :: module()
  def gettext_module do
    Application.get_env(:gettext_mapper, :gettext) ||
      raise(
        "gettext_mapper expects :gettext to be configured. " <>
          "Please add `config :gettext_mapper, gettext: YourApp.Gettext` to your config files."
      )
  end
end
