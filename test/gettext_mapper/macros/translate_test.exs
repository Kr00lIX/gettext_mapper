# Define test app module at module level to have access to configuration
defmodule TestApp do
  use Gettext, backend: MyGettextApp
  use GettextMapper

  def country do
    %{
      name:
        gettext_mapper(%{
          "en" => "United States",
          "de" => "Vereinigte Staaten",
          "uk" => "Сполучені Штати"
        }),
      short_name: gettext_mapper(gettext("USA"))
    }
  end
end

defmodule GettextMapper.TranslateTest do
  use ExUnit.Case, async: true

  use Gettext, backend: MyGettextApp
  use GettextMapper

  test "translate_map/2 with gettext calls" do
    # With .po files present, the macro generates a map with actual translations
    result = gettext_mapper(gettext("Hello"))
    expected = %{"de" => "Hallo!", "en" => "Hello!", "uk" => "Привіт!"}
    assert result == expected
  end

  test "main API usage example" do
    # Define the module outside of the test to avoid compile-time issues
    result = TestApp.country()

    # Check that we get properly structured maps
    assert is_map(result.name)
    assert is_map(result.short_name)

    # Check static translation map
    assert result.name == %{
             "en" => "United States",
             "de" => "Vereinigte Staaten",
             "uk" => "Сполучені Штати"
           }

    # Check gettext-generated map
    expected_short_name = %{"de" => "USA", "en" => "USA", "uk" => "США"}
    assert result.short_name == expected_short_name
  end

  test "translate_map/2 with static translation maps" do
    # Test with a translation map using known locales
    translation_map = %{
      "en" => "Advice if the treatment warranty can not be fulfilled",
      "de" => "Rådgivning, hvis behandlingsgarantien ikke kan overholdes",
      "uk" => "Рада щодо гарантії лікування"
    }

    result = gettext_mapper(translation_map)
    assert result == translation_map
  end

  test "validate_translation_map!/2" do
    valid_map = %{
      "en" => "Hello",
      "de" => "Hallo",
      "uk" => "Привіт"
    }

    # Valid map should not raise
    assert GettextMapper.Macros.validate_translation_map!(valid_map, ["en", "de", "uk"]) == :ok

    # Missing locale should raise
    incomplete_map = %{"en" => "Hello", "de" => "Hallo"}

    assert_raise ArgumentError, ~r/missing required locales/, fn ->
      GettextMapper.Macros.validate_translation_map!(incomplete_map, ["en", "de", "uk"])
    end

    # Extra locale should raise
    extra_map = %{"en" => "Hello", "de" => "Hallo", "uk" => "Привіт", "fr" => "Bonjour"}

    assert_raise ArgumentError, ~r/unsupported locales/, fn ->
      GettextMapper.Macros.validate_translation_map!(extra_map, ["en", "de", "uk"])
    end

    # Non-string value should raise
    invalid_value_map = %{"en" => "Hello", "de" => "Hallo", "uk" => 123}

    assert_raise ArgumentError, ~r/non-string values/, fn ->
      GettextMapper.Macros.validate_translation_map!(invalid_value_map, ["en", "de", "uk"])
    end

    # Non-map should raise
    assert_raise ArgumentError, ~r/Expected a map/, fn ->
      GettextMapper.Macros.validate_translation_map!("not a map", ["en", "de", "uk"])
    end
  end
end
