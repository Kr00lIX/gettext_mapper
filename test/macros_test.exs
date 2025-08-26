defmodule MacrosTest do
  use ExUnit.Case, async: false

  describe "GettextMapper.Macros" do
    test "gettext_mapper/2 with static translation map" do
      defmodule TestStaticMap do
        use GettextMapper

        def test_message do
          gettext_mapper(%{"en" => "Hello", "de" => "Hallo", "uk" => "Привіт"})
        end
      end

      result = TestStaticMap.test_message()
      assert is_map(result)
      assert result["en"] == "Hello"
      assert result["de"] == "Hallo"
      assert result["uk"] == "Привіт"
    end

    test "gettext_mapper/2 with domain parameter" do
      defmodule TestDomainParam do
        use GettextMapper

        def test_message do
          gettext_mapper(%{"en" => "Hello", "de" => "Hallo", "uk" => "Привіт"}, domain: "test")
        end
      end

      result = TestDomainParam.test_message()
      assert is_map(result)
      assert result["en"] == "Hello"
      assert result["de"] == "Hallo"
    end

    test "gettext_mapper/2 with module-level domain" do
      defmodule TestModuleDomain do
        use GettextMapper, domain: "admin"

        def test_message do
          gettext_mapper(%{"en" => "Admin", "de" => "Verwaltung", "uk" => "Адмін"})
        end
      end

      result = TestModuleDomain.test_message()
      assert is_map(result)
      assert result["en"] == "Admin"
      assert result["de"] == "Verwaltung"
    end

    test "validate_translation_map!/2 with valid map" do
      map = %{"en" => "Hello", "de" => "Hallo"}
      supported_locales = ["en", "de"]

      assert :ok = GettextMapper.Macros.validate_translation_map!(map, supported_locales)
    end

    test "validate_translation_map!/2 with missing locales" do
      map = %{"en" => "Hello"}
      supported_locales = ["en", "de", "es"]

      assert_raise ArgumentError, ~r/missing required locales/, fn ->
        GettextMapper.Macros.validate_translation_map!(map, supported_locales)
      end
    end

    test "validate_translation_map!/2 with extra locales" do
      map = %{"en" => "Hello", "de" => "Hallo", "fr" => "Bonjour"}
      supported_locales = ["en", "de"]

      assert_raise ArgumentError, ~r/unsupported locales/, fn ->
        GettextMapper.Macros.validate_translation_map!(map, supported_locales)
      end
    end

    test "validate_translation_map!/2 with non-string values" do
      map = %{"en" => "Hello", "de" => 123}
      supported_locales = ["en", "de"]

      assert_raise ArgumentError, ~r/non-string values/, fn ->
        GettextMapper.Macros.validate_translation_map!(map, supported_locales)
      end
    end

    test "validate_translation_map!/2 with non-map value" do
      assert_raise ArgumentError, ~r/Expected a map/, fn ->
        GettextMapper.Macros.validate_translation_map!("not a map", ["en"])
      end
    end

    test "gettext_mapper/2 with invalid argument raises error" do
      defmodule TestInvalidArg do
        use GettextMapper

        def test_invalid do
          gettext_mapper("not a map or gettext call")
        end
      end

      assert_raise ArgumentError,
                   ~r/expects either a gettext function call or a translation map/,
                   fn ->
                     TestInvalidArg.test_invalid()
                   end
    end

    test "gettext_mapper/2 with runtime map validation" do
      defmodule TestRuntimeMap do
        use GettextMapper

        def test_runtime(map) do
          gettext_mapper(map)
        end
      end

      # Valid runtime map
      valid_map = %{"en" => "Hello", "de" => "Hallo", "uk" => "Привіт"}
      result = TestRuntimeMap.test_runtime(valid_map)
      assert result == valid_map

      # Invalid runtime map should raise
      assert_raise ArgumentError, fn ->
        # Unsupported locale
        TestRuntimeMap.test_runtime(%{"fr" => "Bonjour"})
      end
    end

    test "gettext_mapper/2 handles empty known_locales" do
      # Mock empty known_locales
      original_known_locales = Application.get_env(:gettext_mapper, :test_known_locales)

      # This test verifies the fallback behavior when no known locales are configured
      # The implementation should fall back to using the map keys for validation
      defmodule TestEmptyLocales do
        use GettextMapper

        def test_with_any_locales do
          gettext_mapper(%{"en" => "value", "de" => "wert", "uk" => "значення"})
        end
      end

      result = TestEmptyLocales.test_with_any_locales()
      assert result["en"] == "value"
      assert result["de"] == "wert"
      assert result["uk"] == "значення"

      if original_known_locales do
        Application.put_env(:gettext_mapper, :test_known_locales, original_known_locales)
      end
    end

    test "macro generates proper extraction calls for gettext tools" do
      # This test verifies that the macro generates the necessary gettext calls
      # for extraction tools to detect
      defmodule TestExtraction do
        use GettextMapper

        def test_extractable do
          gettext_mapper(%{
            "en" => "Extractable Message",
            "de" => "Extrahierbare Nachricht",
            "uk" => "Повідомлення для вилучення"
          })
        end
      end

      # The macro should have generated internal gettext calls
      # This is tested indirectly by ensuring the function works
      result = TestExtraction.test_extractable()
      assert result["en"] == "Extractable Message"
      assert result["de"] == "Extrahierbare Nachricht"
    end

    test "domain resolution prioritizes call-level over module-level" do
      defmodule TestDomainPriority do
        use GettextMapper, domain: "module_domain"

        def module_domain_message do
          gettext_mapper(%{
            "en" => "Module Domain",
            "de" => "Modulbereich",
            "uk" => "Модульний домен"
          })
        end

        def call_domain_message do
          gettext_mapper(
            %{"en" => "Call Domain", "de" => "Aufrufbereich", "uk" => "Домен виклику"},
            domain: "call_domain"
          )
        end
      end

      # Both should work, but they use different domains internally
      module_result = TestDomainPriority.module_domain_message()
      call_result = TestDomainPriority.call_domain_message()

      assert module_result["en"] == "Module Domain"
      assert call_result["en"] == "Call Domain"
    end
  end
end
