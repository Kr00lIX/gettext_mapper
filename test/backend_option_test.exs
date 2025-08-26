defmodule BackendOptionTest do
  use ExUnit.Case, async: false

  # Define a mock backend for testing
  defmodule TestBackend do
    use Gettext.Backend, otp_app: :gettext_mapper, priv: "test/priv/test_backend"

    def __gettext__(:default_locale), do: "en"
    def __gettext__(:default_domain), do: "default"
  end

  test "module with backend option compiles successfully" do
    # Store original supported_locales to restore later
    original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)

    # Set supported locales that match our test data
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    # Test that using GettextMapper with backend option works
    defmodule TestModuleWithBackend do
      use GettextMapper, backend: BackendOptionTest.TestBackend

      def test_function do
        gettext_mapper(%{"en" => "Test Message"})
      end
    end

    # Should compile and execute without errors
    assert %{"en" => "Test Message"} == TestModuleWithBackend.test_function()

    # Restore original configuration
    if original_supported_locales do
      Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
    else
      Application.delete_env(:gettext_mapper, :supported_locales)
    end
  end

  test "module with both backend and domain options compiles successfully" do
    # Store original supported_locales to restore later
    original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    defmodule TestModuleWithBoth do
      use GettextMapper, backend: BackendOptionTest.TestBackend, domain: "test"

      def test_function do
        gettext_mapper(%{"en" => "Test Message"})
      end
    end

    # Should compile and execute without errors
    assert %{"en" => "Test Message"} == TestModuleWithBoth.test_function()

    # Restore original configuration
    if original_supported_locales do
      Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
    else
      Application.delete_env(:gettext_mapper, :supported_locales)
    end
  end

  test "module without backend option uses global config" do
    # Store original supported_locales to restore later
    original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    defmodule TestModuleWithoutBackend do
      use GettextMapper

      def test_function do
        gettext_mapper(%{"en" => "Test Message"})
      end
    end

    # Should compile and execute without errors using global backend
    assert %{"en" => "Test Message"} == TestModuleWithoutBackend.test_function()

    # Restore original configuration
    if original_supported_locales do
      Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
    else
      Application.delete_env(:gettext_mapper, :supported_locales)
    end
  end

  test "backend option is correctly applied in macro expansion" do
    # Store original supported_locales to restore later
    original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    # We can test this indirectly by ensuring the compilation succeeds
    # and the backend is used for gettext operations

    defmodule TestBackendUsage do
      use GettextMapper, backend: BackendOptionTest.TestBackend

      def test_message do
        gettext_mapper(%{"en" => "Backend Test"})
      end
    end

    # The fact that this compiles and runs means the backend option is working
    result = TestBackendUsage.test_message()
    assert is_map(result)
    assert result["en"] == "Backend Test"

    # Restore original configuration
    if original_supported_locales do
      Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
    else
      Application.delete_env(:gettext_mapper, :supported_locales)
    end
  end

  test "backend attribute is accessible in macro expansion" do
    # This test uses a custom macro to verify the backend attribute is set correctly
    defmodule TestMacroAccess do
      defmacro check_backend_attribute() do
        backend = Module.get_attribute(__CALLER__.module, :__gettext_backend__)

        quote do
          unquote(backend)
        end
      end
    end

    # Store original supported_locales to restore later
    original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    defmodule TestBackendAttribute do
      use GettextMapper, backend: BackendOptionTest.TestBackend
      import TestMacroAccess

      def get_backend_from_attribute do
        check_backend_attribute()
      end

      def test_function do
        gettext_mapper(%{"en" => "Test"})
      end
    end

    # Verify the backend attribute is correctly set and accessible
    assert TestBackendAttribute.get_backend_from_attribute() == BackendOptionTest.TestBackend

    # Verify functionality still works
    assert %{"en" => "Test"} == TestBackendAttribute.test_function()

    # Restore original configuration
    if original_supported_locales do
      Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
    else
      Application.delete_env(:gettext_mapper, :supported_locales)
    end
  end

  test "backend option works with translation validation" do
    # Store original supported_locales to restore later
    original_supported_locales = Application.get_env(:gettext_mapper, :supported_locales)

    # Set custom supported locales for this test
    Application.put_env(:gettext_mapper, :supported_locales, ["en", "test_locale"])

    defmodule TestValidationWithBackend do
      use GettextMapper, backend: BackendOptionTest.TestBackend

      def valid_translation do
        gettext_mapper(%{"en" => "Hello", "test_locale" => "Test"})
      end

      def invalid_translation do
        # This should raise due to missing required locale
        gettext_mapper(%{"en" => "Hello"})
      end
    end

    # Valid translation should work
    assert %{"en" => "Hello", "test_locale" => "Test"} ==
             TestValidationWithBackend.valid_translation()

    # Invalid translation should raise validation error
    assert_raise ArgumentError, ~r/missing required locales/, fn ->
      TestValidationWithBackend.invalid_translation()
    end

    # Restore original configuration
    if original_supported_locales do
      Application.put_env(:gettext_mapper, :supported_locales, original_supported_locales)
    else
      Application.delete_env(:gettext_mapper, :supported_locales)
    end
  end
end
