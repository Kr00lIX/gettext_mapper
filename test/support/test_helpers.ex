defmodule GettextMapper.TestHelpers do
  @moduledoc """
  Shared test utilities for GettextMapper test suite.

  Import this module in tests that need to manage Application configuration
  or Gettext locale state safely.

  ## Usage

      defmodule MyTest do
        use ExUnit.Case
        import GettextMapper.TestHelpers

        test "with custom config" do
          with_app_env(:gettext_mapper, :supported_locales, ["en", "fr"], fn ->
            assert GettextMapper.GettextAPI.known_locales() == ["en", "fr"]
          end)
        end
      end
  """

  @doc """
  Temporarily sets an Application environment variable for the duration of the function.

  Properly restores the original value (or deletes the key if it was unset) after
  the function completes, even if it raises an exception.

  ## Examples

      with_app_env(:gettext_mapper, :supported_locales, ["en", "de"], fn ->
        # Config is set to ["en", "de"] here
        assert GettextMapper.GettextAPI.known_locales() == ["en", "de"]
      end)
      # Original config is restored here
  """
  def with_app_env(app, key, value, func) do
    original = Application.get_env(app, key)

    try do
      Application.put_env(app, key, value)
      func.()
    after
      restore_app_env(app, key, original)
    end
  end

  @doc """
  Temporarily removes an Application environment variable for the duration of the function.

  Properly restores the original value after the function completes.

  ## Examples

      with_app_env_deleted(:gettext_mapper, :supported_locales, fn ->
        # Config key is deleted here
        assert Application.get_env(:gettext_mapper, :supported_locales) == nil
      end)
      # Original config is restored here
  """
  def with_app_env_deleted(app, key, func) do
    original = Application.get_env(app, key)

    try do
      Application.delete_env(app, key)
      func.()
    after
      restore_app_env(app, key, original)
    end
  end

  @doc """
  Temporarily sets Gettext locale for the duration of the function.

  Properly restores the original locale after the function completes.

  ## Examples

      with_locale(MyGettextApp, "de", fn ->
        assert Gettext.get_locale(MyGettextApp) == "de"
      end)
      # Original locale is restored here
  """
  def with_locale(backend, locale, func) do
    original = Gettext.get_locale(backend)

    try do
      Gettext.put_locale(backend, locale)
      func.()
    after
      Gettext.put_locale(backend, original)
    end
  end

  @doc """
  Creates a temporary file with the given content and ensures cleanup.

  The file is automatically deleted after the function completes.

  ## Examples

      with_temp_file("test_module.ex", "defmodule Test do end", fn path ->
        assert File.exists?(path)
        content = File.read!(path)
        assert content =~ "defmodule Test"
      end)
      # File is deleted here
  """
  def with_temp_file(filename, content, func) do
    File.write!(filename, content)

    try do
      func.(filename)
    after
      File.rm(filename)
    end
  end

  @doc """
  Creates a temporary directory and ensures cleanup.

  The directory and all its contents are automatically deleted after the function completes.

  ## Examples

      with_temp_dir("test_priv", fn dir ->
        File.write!(Path.join(dir, "test.txt"), "content")
        assert File.exists?(Path.join(dir, "test.txt"))
      end)
      # Directory and contents are deleted here
  """
  def with_temp_dir(dirname, func) do
    File.mkdir_p!(dirname)

    try do
      func.(dirname)
    after
      File.rm_rf!(dirname)
    end
  end

  # Private helpers

  defp restore_app_env(app, key, nil) do
    Application.delete_env(app, key)
  end

  defp restore_app_env(app, key, value) do
    Application.put_env(app, key, value)
  end
end
