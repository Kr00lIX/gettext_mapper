defmodule SupportedLocalesTest do
  use ExUnit.Case, async: false

  alias GettextMapper.GettextAPI

  setup do
    original = Application.get_env(:gettext_mapper, :supported_locales)
    on_exit(fn -> restore_config(original) end)
    :ok
  end

  defp restore_config(nil), do: Application.delete_env(:gettext_mapper, :supported_locales)
  defp restore_config(value), do: Application.put_env(:gettext_mapper, :supported_locales, value)

  test "supported_locales configuration works end-to-end" do
    custom_locales = ["en", "fr", "jp", "custom_locale"]
    Application.put_env(:gettext_mapper, :supported_locales, custom_locales)

    # Verify GettextAPI returns configured locales
    assert GettextAPI.known_locales() == custom_locales

    # Test that Ecto type validates against configured locales
    alias GettextMapper.Ecto.Type.Translated

    # Should accept valid locales
    assert {:ok, %{"en" => "Hello", "fr" => "Bonjour"}} ==
             Translated.cast(%{"en" => "Hello", "fr" => "Bonjour"})

    # Should accept custom locale
    assert {:ok, %{"custom_locale" => "Custom"}} ==
             Translated.cast(%{"custom_locale" => "Custom"})

    # Should reject unsupported locale
    assert :error == Translated.cast(%{"unsupported" => "Test"})

    # Test with nil values (should be accepted)
    assert {:ok, %{"en" => nil, "fr" => "Bonjour"}} ==
             Translated.cast(%{"en" => nil, "fr" => "Bonjour"})
  end

  test "gettext_mapper macro validates against configured supported_locales" do
    Application.put_env(:gettext_mapper, :supported_locales, ["en", "de"])

    defmodule TestSupportedLocales do
      use GettextMapper

      def valid_translation do
        gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
      end

      def invalid_translation do
        gettext_mapper(%{"en" => "Hello", "fr" => "Bonjour"})
      end
    end

    # Valid translation should work
    assert %{"en" => "Hello", "de" => "Hallo"} == TestSupportedLocales.valid_translation()

    # Invalid translation should raise validation error for missing locale
    assert_raise ArgumentError, ~r/missing required locales/, fn ->
      TestSupportedLocales.invalid_translation()
    end
  end
end
