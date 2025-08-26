defmodule GettextMapper.GettextAPITest do
  use ExUnit.Case, async: true

  alias GettextMapper.GettextAPI

  describe "GettextMapper.GettextAPI" do
    test "locale/0 returns current locale" do
      # The locale should be set by the test helper
      locale = GettextAPI.locale()
      assert is_binary(locale)
      # Default from test setup
      assert locale == "en"
    end

    test "known_locales/0 returns list of known locales" do
      locales = GettextAPI.known_locales()
      assert is_list(locales)
      assert "en" in locales
      assert "de" in locales
      assert "uk" in locales
    end

    test "default_locale/0 returns default locale" do
      default_locale = GettextAPI.default_locale()
      assert is_binary(default_locale)
      assert default_locale == "en"
    end

    test "default_domain/0 returns default domain" do
      default_domain = GettextAPI.default_domain()
      assert is_binary(default_domain)
      assert default_domain == "default"
    end

    test "gettext_module/0 returns configured backend" do
      backend = GettextAPI.gettext_module()
      assert is_atom(backend)
      assert backend == MyGettextApp
    end

    test "gettext_module/0 raises when not configured" do
      # Temporarily remove the configuration
      old_config = Application.get_env(:gettext_mapper, :gettext)
      Application.delete_env(:gettext_mapper, :gettext)

      assert_raise RuntimeError, ~r/expects :gettext to be configured/, fn ->
        GettextAPI.gettext_module()
      end

      # Restore configuration
      if old_config do
        Application.put_env(:gettext_mapper, :gettext, old_config)
      end
    end

    test "locale changes affect locale/0 return value" do
      original_locale = GettextAPI.locale()

      # Change locale
      Gettext.put_locale(MyGettextApp, "de")
      assert GettextAPI.locale() == "de"

      # Change back
      Gettext.put_locale(MyGettextApp, "uk")
      assert GettextAPI.locale() == "uk"

      # Restore original
      Gettext.put_locale(MyGettextApp, original_locale)
      assert GettextAPI.locale() == original_locale
    end

    test "functions work with different backend configurations" do
      # Test with the configured backend
      assert is_binary(GettextAPI.locale())
      assert is_list(GettextAPI.known_locales())
      assert is_binary(GettextAPI.default_locale())
      assert is_binary(GettextAPI.default_domain())
      assert is_atom(GettextAPI.gettext_module())
    end

    test "all functions return expected types" do
      # Type checking for API consistency
      assert is_binary(GettextAPI.locale())
      assert is_list(GettextAPI.known_locales())
      assert Enum.all?(GettextAPI.known_locales(), &is_binary/1)
      assert is_binary(GettextAPI.default_locale())
      assert is_binary(GettextAPI.default_domain())
      assert is_atom(GettextAPI.gettext_module())
    end

    test "default_locale is included in known_locales" do
      default_locale = GettextAPI.default_locale()
      known_locales = GettextAPI.known_locales()

      assert default_locale in known_locales
    end

    test "current locale may or may not be in known_locales" do
      # This is expected behavior - current locale can be set to any value
      # but known_locales are those with .po files
      current_locale = GettextAPI.locale()
      known_locales = GettextAPI.known_locales()

      # The current locale might not be in known_locales if it's set dynamically
      # This test just ensures the API works correctly
      assert is_binary(current_locale)
      assert is_list(known_locales)
    end

    test "supported_locales configuration takes priority over gettext backend" do
      # Store original configuration
      original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)

      # Set custom supported locales
      Application.put_env(:gettext_mapper, :supported_locales, ["en", "custom", "test"])

      # Should return configured locales instead of backend locales
      assert GettextAPI.known_locales() == ["en", "custom", "test"]

      # Restore original configuration
      if original_supported_locales do
        Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
      else
        Application.delete_env(:gettext_mapper, :supported_locales)
      end
    end

    test "falls back to gettext backend when no supported_locales configured" do
      # Store original configuration
      original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)

      # Remove supported_locales configuration
      Application.delete_env(:gettext_mapper, :supported_locales)

      # Should fall back to backend locales
      backend_locales = Gettext.known_locales(MyGettextApp)
      assert GettextAPI.known_locales() == backend_locales

      # Restore original configuration
      if original_supported_locales do
        Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
      end
    end
  end
end
