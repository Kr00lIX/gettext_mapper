defmodule BackendOptionTest do
  use ExUnit.Case, async: false

  # Define a mock backend for testing
  defmodule TestBackend do
    use Gettext.Backend, otp_app: :gettext_mapper, priv: "test/priv/test_backend"

    def __gettext__(:default_locale), do: "en"
    def __gettext__(:default_domain), do: "default"
  end

  # Store and restore supported_locales for all tests in this module
  setup do
    original = Application.get_env(:gettext_mapper, :supported_locales)
    on_exit(fn -> restore_config(original) end)
    {:ok, original_locales: original}
  end

  defp restore_config(nil), do: Application.delete_env(:gettext_mapper, :supported_locales)
  defp restore_config(value), do: Application.put_env(:gettext_mapper, :supported_locales, value)

  test "module with backend option compiles successfully" do
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    defmodule TestModuleWithBackend do
      use GettextMapper, backend: BackendOptionTest.TestBackend

      def test_function do
        gettext_mapper(%{"en" => "Test Message"})
      end
    end

    assert %{"en" => "Test Message"} == TestModuleWithBackend.test_function()
  end

  test "module with both backend and domain options compiles successfully" do
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    defmodule TestModuleWithBoth do
      use GettextMapper, backend: BackendOptionTest.TestBackend, domain: "test"

      def test_function do
        gettext_mapper(%{"en" => "Test Message"})
      end
    end

    assert %{"en" => "Test Message"} == TestModuleWithBoth.test_function()
  end

  test "module without backend option uses global config" do
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    defmodule TestModuleWithoutBackend do
      use GettextMapper

      def test_function do
        gettext_mapper(%{"en" => "Test Message"})
      end
    end

    assert %{"en" => "Test Message"} == TestModuleWithoutBackend.test_function()
  end

  test "backend option is correctly applied in macro expansion" do
    Application.put_env(:gettext_mapper, :supported_locales, ["en"])

    defmodule TestBackendUsage do
      use GettextMapper, backend: BackendOptionTest.TestBackend

      def test_message do
        gettext_mapper(%{"en" => "Backend Test"})
      end
    end

    result = TestBackendUsage.test_message()
    assert is_map(result)
    assert result["en"] == "Backend Test"
  end

  test "backend attribute is accessible in macro expansion" do
    defmodule TestMacroAccess do
      defmacro check_backend_attribute do
        backend = Module.get_attribute(__CALLER__.module, :__gettext_backend__)

        quote do
          unquote(backend)
        end
      end
    end

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

    assert TestBackendAttribute.get_backend_from_attribute() == BackendOptionTest.TestBackend
    assert %{"en" => "Test"} == TestBackendAttribute.test_function()
  end

  test "backend option works with translation validation" do
    Application.put_env(:gettext_mapper, :supported_locales, ["en", "test_locale"])

    defmodule TestValidationWithBackend do
      use GettextMapper, backend: BackendOptionTest.TestBackend

      def valid_translation do
        gettext_mapper(%{"en" => "Hello", "test_locale" => "Test"})
      end

      def invalid_translation do
        gettext_mapper(%{"en" => "Hello"})
      end
    end

    assert %{"en" => "Hello", "test_locale" => "Test"} ==
             TestValidationWithBackend.valid_translation()

    assert_raise ArgumentError, ~r/missing required locales/, fn ->
      TestValidationWithBackend.invalid_translation()
    end
  end
end
