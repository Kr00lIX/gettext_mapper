defmodule GettextMapper do
  @moduledoc """
  GettextMapper provides helper functions and macros for handling localized strings
  with seamless integration into Gettext workflows.

  This library allows you to work with translation maps that can be stored in databases
  or other data structures, while maintaining compatibility with Gettext's extraction
  and translation management tools.

  ## Features

  - **Database Integration**: Store translations as JSON maps in your database
  - **Gettext Compatibility**: Extract messages for translation using standard Gettext tools
  - **Domain Support**: Use Gettext domains for organizing translations by context
  - **Automatic Sync**: Keep your code in sync with .po file updates
  - **Ecto Integration**: Built-in Ecto types for storing translations

  ## Basic Usage

      defmodule MyApp.Product do
        use GettextMapper

        def name do
          # Static translation map - extractable by Gettext
          gettext_mapper(%{"en" => "Product Name"})
        end

        def description(translation_map) do
          # Runtime localization of stored translations
          GettextMapper.localize(translation_map, "No description")
        end
      end

  ## Domain Support

      defmodule MyApp.AdminPanel do
        use GettextMapper, domain: "admin"

        def title do
          gettext_mapper(%{"en" => "Admin Panel"})
        end

        def error_message do
          # Override domain at call level
          gettext_mapper(%{"en" => "Error occurred"}, domain: "errors")
        end
      end

  ## Database Integration

      # In your schema
      defmodule MyApp.Post do
        use Ecto.Schema

        schema "posts" do
          field :title_translations, GettextMapper.Ecto.Type.Translated
          field :content_translations, GettextMapper.Ecto.Type.Translated
        end

        def title(post) do
          GettextMapper.localize(post.title_translations)
        end
      end

  ## Mix Tasks

  - `mix gettext_mapper.sync` - Sync static maps with .po file changes
  - `mix gettext_mapper.extract` - Extract translations to populate .po files

  ## Configuration

      # config/config.exs
      config :gettext_mapper,
        gettext: MyApp.Gettext,
        default_translation: "Missing Translation",
        supported_locales: ["en", "de", "es", "fr"]

  You can also specify a custom backend per module:

      defmodule MyApp.SpecialModule do
        use GettextMapper, backend: MyApp.SpecialGettext

        def message do
          gettext_mapper(%{"en" => "Special message"})
        end
      end
  """

  alias GettextMapper.GettextAPI

  @doc """
  Imports GettextMapper macros into the current module.

  ## Options

  - `:domain` - The Gettext domain to use for all `gettext_mapper/1` calls in this module.
    Defaults to the configured default domain (usually "default").
  - `:backend` - The Gettext backend module to use for this module.
    Defaults to the globally configured backend.

  ## Examples

      # Use default domain and backend
      defmodule MyApp.User do
        use GettextMapper

        def greeting do
          gettext_mapper(%{"en" => "Hello!"})
        end
      end

      # Use specific domain
      defmodule MyApp.AdminPanel do
        use GettextMapper, domain: "admin"

        def title do
          gettext_mapper(%{"en" => "Admin Panel"})
        end
      end

      # Use specific backend
      defmodule MyApp.SpecialModule do
        use GettextMapper, backend: MyApp.SpecialGettext

        def message do
          gettext_mapper(%{"en" => "Special Message"})
        end
      end

      # Use both custom domain and backend
      defmodule MyApp.CustomModule do
        use GettextMapper, domain: "custom", backend: MyApp.CustomGettext

        def content do
          gettext_mapper(%{"en" => "Custom Content"})
        end
      end
  """
  defmacro __using__(opts) do
    domain = Keyword.get(opts, :domain, GettextMapper.GettextAPI.default_domain())
    Module.put_attribute(__CALLER__.module, :__gettext_domain__, domain)

    with {:ok, backend} <- Keyword.fetch(opts, :backend),
         backend when is_atom(backend) and backend not in [nil, false, true] <-
           Macro.expand(backend, __CALLER__) do
      Module.put_attribute(__CALLER__.module, :__gettext_backend__, backend)
    end

    quote do
      import GettextMapper.Macros
      @gettext_mapper_domain unquote(domain)

      # Set backend if provided, otherwise it will be nil and fallback to global config
      # @__gettext_backend__ unquote(backend)
    end
  end

  @doc """
  Returns the localized string from a translations map for the current locale.

  Falls back to the default locale, then to the given default value.

  Examples, when the locale is "en" (default) and default fallback locale is "en":

    # use current locale
    iex> GettextMapper.localize(%{"en" => "Hello", "de" => "Hallo"}, "missed translation")
    "Hello"

    # use fallback locale
    iex> GettextMapper.localize(%{"en" => "Hello", "nb" => "Hallo"})
    "Hello"

    iex> GettextMapper.localize(%{"da" => "Hallo", "fr" => "Bonjour"})
    ""

    # use default translation
    iex> GettextMapper.localize(%{"da" => "Hallo", "fr" => "Bonjour"}, "Default")
    "Default"
  """
  @spec localize(map() | nil, String.t()) :: String.t()
  def localize(value, _default \\ "")

  def localize(nil, _default), do: ""

  def localize(value, default) when is_map(value) do
    value[GettextAPI.locale()] || value[GettextAPI.default_locale()] || default
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
      str = Map.get(values, GettextAPI.default_locale()) -> str
      true -> default_translation()
    end
  end

  # Retrieves the default translation message from config, defaulting to "NO TRANSLATION".
  defp default_translation do
    Application.get_env(:gettext_mapper, :default_translation, "NO TRANSLATION")
  end
end
