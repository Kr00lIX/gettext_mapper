defmodule ProductModule do
  use Gettext, backend: MyGettextApp
  use GettextMapper

  def description do
    gettext_mapper(%{"de" => "Willkommen!", "en" => "Welcome!", "uk" => "Ласкаво просимо!"})
  end
end
