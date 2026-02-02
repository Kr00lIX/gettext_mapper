defmodule GettextMapper.Ecto.Type.Translated do
  @moduledoc """
  Ecto custom type for storing translation maps in a database.

  This type allows you to store translations as JSON maps in your database
  while providing validation against configured supported locales.

  ## Schema Usage

      defmodule MyApp.Product do
        use Ecto.Schema

        schema "products" do
          field :name, GettextMapper.Ecto.Type.Translated
          field :description, GettextMapper.Ecto.Type.Translated
        end
      end

  ## Migration Example

      def change do
        create table(:products) do
          add :name, :map
          add :description, :map
        end
      end

  ## Storing Translations

      product = %Product{}
      |> Ecto.Changeset.change(%{
        name: %{"en" => "Product", "de" => "Produkt"},
        description: %{"en" => "A great product", "de" => "Ein tolles Produkt"}
      })
      |> Repo.insert!()

  ## Retrieving Localized Values

      product = Repo.get!(Product, 1)
      GettextMapper.localize(product.name)  # Returns "Product" when locale is "en"

  ## Validation

  The type validates that:
  - All keys are in the configured `supported_locales` list
  - All values are strings or nil

  Configure supported locales in your application config:

      config :gettext_mapper,
        gettext: MyApp.Gettext,
        supported_locales: ["en", "de", "es", "fr"]
  """

  use Ecto.Type

  @doc """
  Returns the underlying database type.

  Returns `:map` since translations are stored as JSON/JSONB maps.

  ## Example

      iex> GettextMapper.Ecto.Type.Translated.type()
      :map
  """
  @spec type() :: :map
  def type, do: :map

  @doc """
  Casts external data to a translation map.

  Validates that:
  - Input is a map
  - All keys are in the configured supported locales
  - All values are strings or nil

  Returns `{:ok, map}` if valid, `:error` otherwise.

  ## Examples

      # Valid translation map
      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.cast(%{"en" => "Hello", "de" => "Hallo"})
      {:ok, %{"en" => "Hello", "de" => "Hallo"}}

      # Nil values are allowed
      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.cast(%{"en" => "Hello", "de" => nil})
      {:ok, %{"en" => "Hello", "de" => nil}}

      # Invalid input type
      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.cast("not a map")
      :error

      # Invalid value type
      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.cast(%{"en" => 123})
      :error
  """
  @spec cast(any()) :: {:ok, map()} | :error
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

  Accepts maps and nil values from the database. Returns `{:ok, value}` for
  valid inputs, `:error` otherwise.

  ## Examples

      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.load(%{"en" => "Hello", "de" => "Hallo"})
      {:ok, %{"en" => "Hello", "de" => "Hallo"}}

      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.load(nil)
      {:ok, nil}

      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.load("invalid")
      :error
  """
  @spec load(any()) :: {:ok, map() | nil} | :error
  def load(params) when is_map(params), do: {:ok, params}
  def load(nil), do: {:ok, nil}
  def load(_), do: :error

  @doc """
  Dumps a value to the database.

  Accepts map values for storing in the database. Returns `{:ok, value}` for
  valid inputs, `:error` otherwise.

  ## Examples

      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.dump(%{"en" => "Hello", "de" => "Hallo"})
      {:ok, %{"en" => "Hello", "de" => "Hallo"}}

      iex> alias GettextMapper.Ecto.Type.Translated
      iex> Translated.dump("invalid")
      :error
  """
  @spec dump(any()) :: {:ok, map()} | :error
  def dump(value) when is_map(value), do: {:ok, value}
  def dump(_), do: :error

  defp supported_locales do
    GettextMapper.GettextAPI.known_locales()
  end
end
