ExUnit.start()

defmodule TestGettext do
  @moduledoc false
  # Simulates a Gettext backend for tests
  def known_locales, do: ["en", "uk", "nb", "de"]
  def get_locale, do: "de"
  def default_locale, do: "en"
end

# Configure the library to use the test Gettext backend
Application.put_env(:gettext_mapper, :gettext, TestGettext)
