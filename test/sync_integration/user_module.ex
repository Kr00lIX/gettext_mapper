defmodule UserModule do
  use Gettext, backend: MyGettextApp
  use GettextMapper

  def simple_greeting do
    gettext_mapper(%{"de" => "Hallo!", "en" => "Hello!", "uk" => "Привіт!"})
  end

  def personal_greeting do
    gettext_mapper(%{
      "en" => "Hello %{name}!",
      "de" => "Hallo %{name}!",
      "uk" => "Привіт %{name}!"
    })
  end

  def welcome do
    gettext_mapper(%{"de" => "Willkommen!", "en" => "Welcome!", "uk" => "Ласкаво просимо!"})
  end
end
