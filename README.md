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

### Basic Example: Subscription Plans with Translations

Let's say you have subscription plans that need translated names and descriptions stored in the database.

**1. Define your schema with translated fields:**

```elixir
defmodule MyApp.SubscriptionPlan do
  use Ecto.Schema

  schema "subscription_plans" do
    field :key, :string
    field :price, :decimal
    field :name, GettextMapper.Ecto.Type.Translated
    field :description, GettextMapper.Ecto.Type.Translated
    timestamps()
  end
end
```

**2. Populate the database with translations using `gettext_mapper`:**

```elixir
defmodule MyApp.Seeds.Plans do
  use GettextMapper

  def seed do
    Repo.insert!(%SubscriptionPlan{
      key: "basic",
      price: Decimal.new("9.99"),
      name: gettext_mapper(%{
        "en" => "Basic Plan",
        "de" => "Basis-Tarif",
        "es" => "Plan Básico"
      }, msgid: "plan.basic.name"),
      description: gettext_mapper(%{
        "en" => "Perfect for individuals getting started",
        "de" => "Perfekt für Einsteiger",
        "es" => "Perfecto para comenzar"
      }, msgid: "plan.basic.description")
    })
  end
end
```

**3. Display localized content based on user's locale:**

```elixir
# In your controller or view
plan = Repo.get_by!(SubscriptionPlan, key: "basic")

# Returns translation for current locale (e.g., "de")
GettextMapper.localize(plan.name)
#=> "Basis-Tarif"

GettextMapper.localize(plan.description, "No description available")
#=> "Perfekt für Einsteiger"
```

**4. Or use `lgettext_mapper` for inline localized strings:**

```elixir
defmodule MyAppWeb.PlanController do
  use GettextMapper

  def index(conn, _params) do
    # Returns the localized string directly for current locale
    page_title = lgettext_mapper(%{
      "en" => "Choose Your Plan",
      "de" => "Wählen Sie Ihren Tarif"
    }, msgid: "plans.page_title")

    render(conn, :index, title: page_title)
  end
end
```

### Key Concepts

| Macro | Returns | Use Case |
|-------|---------|----------|
| `gettext_mapper/2` | Map of all translations | Storing in database |
| `lgettext_mapper/2` | Localized string | Displaying to user |
| `GettextMapper.localize/2` | Localized string | Reading from database |

### Additional Features

#### Custom Message IDs

Use stable translation keys instead of text as the gettext msgid:

```elixir
gettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, msgid: "greeting.hello")
```

This creates .po entries with stable keys that don't change when text changes:

```po
msgid "greeting.hello"
msgstr "Hallo"
```

#### Domain Support

Organize translations by domain:

```elixir
defmodule MyApp.Admin do
  use GettextMapper, domain: "admin"

  def title do
    lgettext_mapper(%{"en" => "Dashboard", "de" => "Übersicht"})
  end
end
```

#### Custom Backend

Use a specific Gettext backend:

```elixir
defmodule MyApp.Legacy do
  use GettextMapper, backend: MyApp.LegacyGettext
end
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
