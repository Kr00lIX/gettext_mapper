# GettextMapper

[![Hex.pm](https://img.shields.io/hexpm/v/gettext_mapper.svg)](https://hex.pm/packages/gettext_mapper)
[![Coverage Status](https://coveralls.io/repos/github/kr00lix/gettext_mapper/badge.svg?branch=main)](https://coveralls.io/github/kr00lix/gettext_mapper?branch=main)
[![Docs](https://img.shields.io/badge/docs-ExDoc-blue.svg)](https://hexdocs.pm/gettext_mapper)

GettextMapper seamlessly bridges the gap between database-stored translations and Gettext's powerful internationalization tools. Store your translations as JSON maps in the database while maintaining full compatibility with Gettext's extraction, synchronization, and management workflows.

## Features

- 🗄️ **Database Integration**: Store translations as JSON maps in your database
- 🔄 **Gettext Compatibility**: Extract messages for translation using standard Gettext tools
- 🏷️ **Domain Support**: Use Gettext domains for organizing translations by context  
- 📦 **Ecto Integration**: Built-in Ecto types for seamless database operations
- 🔄 **Auto Synchronization**: Keep your code in sync with .po file updates
- 📝 **Mix Tasks**: Powerful CLI tools for managing translations
- 🎯 **Smart Fallbacks**: Automatic fallback to default locale and custom defaults
- ⚡ **Runtime Flexibility**: Switch locales dynamically at runtime

## Installation

Add `gettext_mapper` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gettext_mapper, "~> 0.1"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Configuration

First, configure your Gettext backend in `config/config.exs`:

```elixir
config :gettext_mapper,
  gettext: MyApp.Gettext,
  # Optional: custom message when no translation is found
  default_translation: "Missing Translation",
  # Optional: explicitly define supported locales (takes priority over auto-discovery)
  supported_locales: ["en", "de", "es", "fr"]
```

The `supported_locales` configuration is particularly useful when:
- You want to restrict which locales are accepted in translation maps
- Your application doesn't have .po files yet but you want to define supported locales
- You want explicit control over locale validation instead of auto-discovery

Make sure you have a Gettext backend module:

```elixir
defmodule MyApp.Gettext do
  use Gettext.Backend, otp_app: :my_app
end
```

## Usage

### 1. Static Translation Maps

Use `gettext_mapper/1` for static translations that should be extracted by Gettext tools:

```elixir
defmodule MyApp.ProductController do
  use GettextMapper

  def index(conn, _params) do
    page_title = gettext_mapper(%{
      "en" => "Product Catalog",
      "de" => "Produktkatalog", 
      "es" => "Catálogo de Productos"
    })
    
    render(conn, "index.html", title: page_title)
  end
end
```

### 2. Database-Stored Translations

Use Ecto types for storing translations in the database:

```elixir
defmodule MyApp.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :name_translations, GettextMapper.Ecto.Type.Translated
    field :description_translations, GettextMapper.Ecto.Type.Translated
    timestamps()
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name_translations, :description_translations])
    |> validate_required([:name_translations])
  end

  # Helper functions for getting localized content
  def name(product), do: GettextMapper.localize(product.name_translations)
  def description(product), do: GettextMapper.localize(product.description_translations, "No description")
end
```

### 3. Domain Support

Organize your translations by domain:

```elixir
defmodule MyApp.AdminPanel do
  use GettextMapper, domain: "admin"

  def dashboard_title do
    gettext_mapper(%{
      "en" => "Admin Dashboard",
      "de" => "Verwaltungsdashboard"
    })
  end

  def error_with_custom_domain do
    # Override module domain for specific calls
    gettext_mapper(%{
      "en" => "Critical Error",
      "de" => "Kritischer Fehler"
    }, domain: "errors")
  end
end
```

### 4. Custom Message IDs

Use stable translation keys instead of text as the gettext msgid:

```elixir
defmodule MyApp.UI do
  use GettextMapper

  def greeting do
    # Uses "ui.greeting" as msgid in .po files instead of "Hello"
    gettext_mapper(%{
      "en" => "Hello",
      "de" => "Hallo"
    }, msgid: "ui.greeting")
  end

  def error_message do
    # Combine msgid with domain
    gettext_mapper(%{
      "en" => "Something went wrong",
      "de" => "Etwas ist schief gelaufen"
    }, msgid: "error.generic", domain: "errors")
  end
end
```

This creates .po entries with stable keys:

```po
# priv/gettext/de/LC_MESSAGES/default.po
msgid "ui.greeting"
msgstr "Hallo"

# priv/gettext/de/LC_MESSAGES/errors.po
msgid "error.generic"
msgstr "Etwas ist schief gelaufen"
```

**Benefits of custom msgid:**
- Translation keys remain stable even when source text changes
- Easier to reference translations in external tools
- Better organization with dot-notation keys (e.g., `module.component.message`)

### 5. Custom Backend Support

Use a specific Gettext backend for a module:

```elixir
# Use a specific Gettext backend for a module
defmodule MyApp.SpecialModule do
  use GettextMapper, backend: MyApp.SpecialGettext

  def special_message do
    gettext_mapper(%{
      "en" => "Special Message",
      "de" => "Spezielle Nachricht"
    })
  end
end

# Combine custom backend with custom domain
defmodule MyApp.LegacyModule do
  use GettextMapper, backend: MyApp.LegacyGettext, domain: "legacy"

  def legacy_content do
    gettext_mapper(%{
      "en" => "Legacy Content",
      "de" => "Legacy Inhalt"
    })
  end
end
```

### 6. Runtime Localization

```elixir
# Set the current locale
Gettext.put_locale(MyApp.Gettext, "de")

# Localize stored translations
translation_map = %{"en" => "Hello", "de" => "Hallo", "es" => "Hola"}
GettextMapper.localize(translation_map)  #=> "Hallo"

# Get specific locale with fallback
GettextMapper.translate(translation_map, "fr")  #=> "Hello" (falls back to default)

# With custom fallback
GettextMapper.localize(translation_map, "Not available")  #=> "Hallo"
```

## Mix Tasks

GettextMapper provides powerful Mix tasks for managing your translations:

### Extract Translations

Extract both message IDs and translations from your static `gettext_mapper` calls to populate .po files:

```bash
# Extract translations from all files
mix gettext_mapper.extract

# Extract from specific files  
mix gettext_mapper.extract lib/my_app/products.ex

# Dry run to see what would be extracted
mix gettext_mapper.extract --dry-run

# Use custom priv directory
mix gettext_mapper.extract --priv priv/my_gettext
```

This creates properly formatted .po files with both `msgid` and `msgstr` entries:

```po
# In priv/gettext/de/LC_MESSAGES/default.po
msgid "Product Catalog"
msgstr "Produktkatalog"

# In priv/gettext/de/LC_MESSAGES/admin.po (domain-specific)
msgid "Admin Dashboard" 
msgstr "Verwaltungsdashboard"
```

### Sync Translations

Keep your static translation maps in sync with .po file updates:

```bash
# Sync all files in lib/
mix gettext_mapper.sync

# Sync specific files
mix gettext_mapper.sync lib/my_app/controllers/

# Dry run to see what would change
mix gettext_mapper.sync --dry-run

# Generate translation map for a specific message
mix gettext_mapper.sync --message "Hello World"
```

When your .po files are updated (e.g., by translators), this task automatically updates your code:

```elixir
# Before sync (outdated)
gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})

# After sync (updated from .po files)  
gettext_mapper(%{"en" => "Hello", "de" => "Hallo Welt"})
```

## Workflow Integration

### Standard Gettext Workflow

1. **Extract messages**: `mix gettext.extract` (extracts from `gettext_mapper` calls)
2. **Generate templates**: `mix gettext.merge priv/gettext`
3. **Translate .po files**: Send to translators or translate manually
4. **Update code**: `mix gettext_mapper.sync` (updates static maps)
5. **Extract full translations**: `mix gettext_mapper.extract` (populates .po files)

### CI/CD Integration

```yaml
# .github/workflows/translations.yml
- name: Check translation sync
  run: |
    mix gettext_mapper.sync --dry-run
    if [ $? -ne 0 ]; then
      echo "Translations are out of sync. Run 'mix gettext_mapper.sync'"
      exit 1
    fi
```

## Advanced Features

### Custom Ecto Types

Create domain-specific Ecto types:

```elixir
defmodule MyApp.Types.ProductTranslation do
  use GettextMapper.Ecto.Type.Base, domain: "products"
end

# Use in schemas
field :name, MyApp.Types.ProductTranslation
```

### Validation

Validate translation completeness:

```elixir
def changeset(struct, attrs) do
  struct
  |> cast(attrs, [:name_translations])
  |> validate_translation_completeness(:name_translations)
end

defp validate_translation_completeness(changeset, field) do
  case get_field(changeset, field) do
    %{} = translations ->
      required_locales = GettextMapper.GettextAPI.known_locales()
      missing = required_locales -- Map.keys(translations)
      
      if Enum.empty?(missing) do
        changeset
      else
        add_error(changeset, field, "missing translations for: #{Enum.join(missing, ", ")}")
      end
    _ -> changeset
  end
end
```

## Testing

Run the test suite:

```bash
# Run all tests
mix test

# With coverage
mix test --cover

# Run specific test files
mix test test/gettext_mapper_test.exs
```

## Documentation

Full documentation is available at [https://hexdocs.pm/gettext_mapper](https://hexdocs.pm/gettext_mapper).

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Ensure all tests pass: `mix test`
5. Run the formatter: `mix format`
6. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.
