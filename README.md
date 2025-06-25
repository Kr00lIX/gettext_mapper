<!--
  This README uses shields.io and coveralls badges; adjust URLs as needed.
-->
# GettextMapper: Ecto.Type for localized JSON translations

[![Hex.pm](https://img.shields.io/hexpm/v/gettext_mapper.svg)](https://hex.pm/packages/gettext_mapper)
[![Coverage Status](https://coveralls.io/repos/github/kr00lix/gettext_mapper/badge.svg?branch=master)](https://coveralls.io/github/kr00lix/gettext_mapper?branch=master)
[![Docs](https://img.shields.io/badge/docs-ExDoc-blue.svg)](https://hexdocs.pm/gettext_mapper)

GettextMapper provides an `Ecto.Type` to store and retrieve translations
as JSON maps keyed by locale. It integrates with a configurable Gettext backend,
offering casts, loads, dumps, and helper functions to fetch localized strings
with fallback support.

## Features

- Store locale-to-string mappings in a single JSON/map column.
- Cast only maps with supported locales defined by your Gettext backend.
- `load/1` and `dump/1` callbacks for seamless Ecto integration.
- `localize/2` to fetch text in the current locale, falling back to default
  locale or a provided default.
- `translate/2` to retrieve text for a specific locale with fallback support.
- Runtime configuration of Gettext backend via application environment.

## Installation

Add the dependency in your `mix.exs`:

```elixir
def deps do
  [
    {:gettext_mapper, "~> 0.1.0"}
  ]
end
```

Fetch dependencies:

```bash
mix deps.get
```

## Configuration

In your `config/config.exs`, point to your Gettext backend:

```elixir
config :gettext_mapper,
  gettext: MyApp.Gettext
```

Ensure your backend module (e.g. `MyApp.Gettext`) uses `Gettext`.

## Usage

### Schema definition

```elixir
defmodule MyApp.Post do
  use Ecto.Schema

  schema "posts" do
    field :title, GettextMapper.Ecto.Type.Translated
  end
end
```

### Working with translations

```elixir
# Casting input in changesets
changeset =
  %MyApp.Post{}
  |> Ecto.Changeset.cast(%{title: %{"en" => "Hello", "nb" => "Hei"}}, [:title])

# Localize for current locale
GettextMapper.localize(changeset.changes.title, "Default text")

# Translate for a specific locale
GettextMapper.translate(changeset.changes.title, "en")
```

## Testing

Internal tests cover `type/0`, `cast/1`, `load/1`, `dump/1`, `localize/2`, and
`translate/2`. Run:

```bash
mix test
mix coveralls
```

## Documentation

Docs are available at [https://hexdocs.pm/gettext_mapper](https://hexdocs.pm/gettext_mapper).

## Contributing

Pull requests and issues are welcome! Please follow
[Elixir's style guide](https://github.com/elixir-lang/elixir/blob/master/.formatter.exs)
and include tests for new functionality.

## License

This project is licensed under the MIT License.

## Author

Kr00liX (https://github.com/kr00lix)
