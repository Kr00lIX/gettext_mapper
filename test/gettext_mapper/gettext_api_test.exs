defmodule GettextMapper.GettextAPITest do
  # Use async: false because some tests modify global Application config
  use ExUnit.Case, async: false
  import GettextMapper.TestHelpers

  alias GettextMapper.GettextAPI

  describe "GettextMapper.GettextAPI" do
    test "locale/0 returns current locale" do
      locale = GettextAPI.locale()
      assert is_binary(locale)
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
      old_config = Application.get_env(:gettext_mapper, :gettext)

      try do
        Application.delete_env(:gettext_mapper, :gettext)

        assert_raise RuntimeError, ~r/expects :gettext to be configured/, fn ->
          GettextAPI.gettext_module()
        end
      after
        Application.put_env(:gettext_mapper, :gettext, old_config)
      end
    end

    test "locale changes affect locale/0 return value" do
      with_locale(MyGettextApp, "de", fn ->
        assert GettextAPI.locale() == "de"
      end)

      with_locale(MyGettextApp, "uk", fn ->
        assert GettextAPI.locale() == "uk"
      end)
    end

    test "functions work with different backend configurations" do
      assert is_binary(GettextAPI.locale())
      assert is_list(GettextAPI.known_locales())
      assert is_binary(GettextAPI.default_locale())
      assert is_binary(GettextAPI.default_domain())
      assert is_atom(GettextAPI.gettext_module())
    end

    test "all functions return expected types" do
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
      current_locale = GettextAPI.locale()
      known_locales = GettextAPI.known_locales()

      assert is_binary(current_locale)
      assert is_list(known_locales)
    end

    test "supported_locales configuration takes priority over gettext backend" do
      original = Application.get_env(:gettext_mapper, :supported_locales)

      try do
        Application.put_env(:gettext_mapper, :supported_locales, ["en", "custom", "test"])
        assert GettextAPI.known_locales() == ["en", "custom", "test"]
      after
        Application.put_env(:gettext_mapper, :supported_locales, original)
      end
    end

    test "falls back to gettext backend when no supported_locales configured" do
      original = Application.get_env(:gettext_mapper, :supported_locales)

      try do
        Application.delete_env(:gettext_mapper, :supported_locales)

        backend_locales = Gettext.known_locales(MyGettextApp)
        assert GettextAPI.known_locales() == backend_locales
      after
        Application.put_env(:gettext_mapper, :supported_locales, original)
      end
    end
  end

  describe "get_backend/1" do
    test "returns configured backend when no options provided" do
      backend = GettextAPI.get_backend([])

      assert backend == MyGettextApp
    end

    test "returns backend from string option" do
      # Module names need "Elixir." prefix when converted from string
      backend = GettextAPI.get_backend(backend: "Elixir.MyGettextApp")

      assert backend == MyGettextApp
    end

    test "returns backend from atom option" do
      backend = GettextAPI.get_backend(backend: MyGettextApp)

      assert backend == MyGettextApp
    end
  end

  describe "priv_dir/1" do
    test "returns priv directory for backend" do
      priv_dir = GettextAPI.priv_dir(MyGettextApp)

      assert is_binary(priv_dir)
      assert String.contains?(priv_dir, "priv") or String.contains?(priv_dir, "gettext")
    end

    test "returns fallback for invalid backend" do
      priv_dir = GettextAPI.priv_dir(NonExistentModule)

      assert priv_dir == "priv/gettext"
    end
  end

  describe "default_locale_for/1" do
    test "returns default locale for backend" do
      locale = GettextAPI.default_locale_for(MyGettextApp)

      assert locale == "en"
    end

    test "returns fallback for invalid backend" do
      locale = GettextAPI.default_locale_for(NonExistentModule)

      assert locale == "en"
    end
  end
end
