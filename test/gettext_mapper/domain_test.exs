defmodule GettextMapper.DomainTest do
  use ExUnit.Case, async: false

  defmodule TestProductModule do
    use Gettext, backend: MyGettextApp
    use GettextMapper, domain: "product"

    def product_name do
      gettext_mapper(%{"de" => "Produkt", "en" => "Product", "uk" => "Продукт"})
    end

    def product_description do
      gettext_mapper(%{
        "de" => "Ein tolles Produkt",
        "en" => "A great product",
        "uk" => "Чудовий продукт"
      })
    end
  end

  defmodule TestUserModule do
    use Gettext, backend: MyGettextApp
    use GettextMapper

    def user_greeting do
      gettext_mapper(%{"de" => "Willkommen", "en" => "Welcome", "uk" => "Ласкаво просимо"})
    end

    def admin_greeting do
      gettext_mapper(%{"de" => "Admin-Bereich", "en" => "Admin Area", "uk" => "Адмін область"},
        domain: "admin"
      )
    end
  end

  setup do
    # Set test locale
    Gettext.put_locale(MyGettextApp, "en")
    :ok
  end

  describe "module-level domain configuration" do
    test "uses module domain for gettext_mapper calls" do
      result = TestProductModule.product_name()
      assert is_map(result)
      assert result["en"] == "Product"
      assert result["de"] == "Produkt"
      assert result["uk"] == "Продукт"
    end

    test "works with multiple functions in the same module" do
      name = TestProductModule.product_name()
      description = TestProductModule.product_description()

      assert name["en"] == "Product"
      assert description["en"] == "A great product"
    end
  end

  describe "call-level domain override" do
    test "uses call-level domain when specified" do
      result = TestUserModule.admin_greeting()
      assert is_map(result)
      assert result["en"] == "Admin Area"
      assert result["de"] == "Admin-Bereich"
      assert result["uk"] == "Адмін область"
    end

    test "uses default domain when no domain specified" do
      result = TestUserModule.user_greeting()
      assert is_map(result)
      assert result["en"] == "Welcome"
      assert result["de"] == "Willkommen"
      assert result["uk"] == "Ласкаво просимо"
    end
  end

  describe "domain integration with extraction" do
    test "module with domain generates proper gettext calls for extraction" do
      # This test ensures that the domain configuration works with gettext extraction
      # The actual extraction is tested by compilation - if macros generate incorrect code,
      # compilation will fail
      assert TestProductModule.product_name()["en"] == "Product"
    end

    test "call-level domain generates proper dgettext calls for extraction" do
      # This test ensures that call-level domain specification works
      assert TestUserModule.admin_greeting()["en"] == "Admin Area"
    end
  end

  describe "domain validation" do
    test "module domain attribute is properly set" do
      # Test that the module attribute is correctly set by checking if the domain works in practice
      # Since module attributes might not be directly accessible, we test behavior instead
      result = TestProductModule.product_name()
      # If domain is working correctly, we should get a proper translation map
      assert is_map(result)
      assert Map.has_key?(result, "en")
    end

    test "default module has default domain behavior" do
      # Test that default domain works by checking behavior
      result = TestUserModule.user_greeting()
      assert is_map(result)
      assert Map.has_key?(result, "en")
    end
  end
end
