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
  - **Custom Message IDs**: Use stable keys instead of text as gettext msgid
  - **Automatic Sync**: Keep your code in sync with .po file updates
  - **Ecto Integration**: Built-in Ecto types for storing translations

  ## Basic Usage

      defmodule MyApp.Product do
        use GettextMapper

        def name do
          # Returns the full translation map
          gettext_mapper(%{"en" => "Product Name", "de" => "Produktname"})
        end

        def title do
          # Returns the localized string for current locale
          lgettext_mapper(%{"en" => "Products", "de" => "Produkte"})
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

  ## Custom Message IDs

  By default, the default locale's text is used as the msgid in gettext .po files.
  You can specify a custom msgid to use stable translation keys instead:

      defmodule MyApp.UI do
        use GettextMapper

        def greeting do
          # Uses "greeting.hello" as msgid in .po files instead of "Hello"
          gettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, msgid: "greeting.hello")
        end

        def error_message do
          # Combine with domain
          gettext_mapper(%{"en" => "Error", "de" => "Fehler"},
            msgid: "error.generic",
            domain: "errors"
          )
        end
      end

  This creates .po entries like:

      # de/LC_MESSAGES/default.po
      msgid "greeting.hello"
      msgstr "Hallo"

  ## Localized Strings (lgettext_mapper)

  Use `lgettext_mapper/2` when you want the translated string directly instead of the map:

      defmodule MyApp.UI do
        use GettextMapper

        def welcome_message do
          # Returns "Hello" when locale is "en", "Hallo" when locale is "de"
          lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
        end

        def error_message do
          # With custom msgid and default fallback
          lgettext_mapper(%{"en" => "Error", "de" => "Fehler"},
            msgid: "error.generic",
            default: "An error occurred"
          )
        end

        def german_greeting do
          # With specific locale (returns "Hallo" regardless of current locale)
          lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, locale: "de")
        end
      end

  The `lgettext_mapper` macro:
  - Returns the translation for the current locale (or specified `:locale`)
  - Falls back to the default locale if current locale not found
  - Falls back to the `:default` option if no translation found
  - Supports all options from `gettext_mapper` (`:domain`, `:msgid`) plus `:locale`

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

  ## Module Options

  - `:domain` - The Gettext domain to use for all `gettext_mapper/1` calls in this module.
    Defaults to the configured default domain (usually "default").
  - `:backend` - The Gettext backend module to use for this module.
    Defaults to the globally configured backend.

  ## Per-Call Options

  The `gettext_mapper/2` macro also accepts options at the call level:

  - `:domain` - Override the module domain for this specific call.
  - `:msgid` - Use a custom message ID instead of the default locale text.
    This is useful for stable translation keys that don't change when text changes.

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

      # Use custom msgid for stable translation keys
      defmodule MyApp.StableKeys do
        use GettextMapper

        def greeting do
          # "ui.greeting" will be the msgid in .po files
          gettext_mapper(%{"en" => "Hello!", "de" => "Hallo!"}, msgid: "ui.greeting")
        end

        def error do
          # Combine msgid with domain
          gettext_mapper(%{"en" => "Error", "de" => "Fehler"},
            msgid: "error.generic",
            domain: "errors"
          )
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

  ## Parameters

  - `value` - The translations map
  - `default` - Fallback value if no translation found (default: "")
  - `locale` - Specific locale to use instead of current locale (default: nil)

  ## Examples

  When the locale is "en" (default) and default fallback locale is "en":

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

    # use specific locale
    iex> GettextMapper.localize(%{"en" => "Hello", "de" => "Hallo"}, "", "de")
    "Hallo"
  """
  @spec localize(map() | nil, String.t(), String.t() | nil) :: String.t()
  def localize(value, default \\ "", locale \\ nil)

  def localize(nil, _default, _locale), do: ""

  def localize(value, default, locale) when is_map(value) do
    effective_locale = locale || GettextAPI.locale()
    value[effective_locale] || value[GettextAPI.default_locale()] || default
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
