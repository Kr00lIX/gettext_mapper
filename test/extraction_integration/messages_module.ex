defmodule MessagesModule do
  use Gettext, backend: MyGettextApp
  use GettextMapper

  def greeting do
    gettext_mapper(%{"en" => "Hello World", "de" => "Hallo Welt", "uk" => "Привіт Світ"})
  end

  def farewell do
    gettext_mapper(%{
      "en" => "Goodbye Friend",
      "de" => "Auf Wiedersehen Freund",
      "uk" => "До побачення друже"
    })
  end

  def welcome_message do
    gettext_mapper(%{
      "en" => "Welcome to our application",
      "de" => "Willkommen in unserer Anwendung",
      "uk" => "Ласкаво просимо до нашого додатку"
    })
  end

  def error_message do
    gettext_mapper(%{
      "en" => "Something went wrong",
      "de" => "Etwas ist schief gelaufen",
      "uk" => "Щось пішло не так"
    })
  end
end
