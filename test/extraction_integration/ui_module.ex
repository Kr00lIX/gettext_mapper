defmodule UIModule do
  use Gettext, backend: MyGettextApp
  use GettextMapper

  def button_labels do
    %{
      save:
        gettext_mapper(%{
          "en" => "Save Changes",
          "de" => "Änderungen speichern",
          "uk" => "Зберегти зміни"
        }),
      cancel: gettext_mapper(%{"en" => "Cancel", "de" => "Abbrechen", "uk" => "Скасувати"}),
      delete:
        gettext_mapper(%{
          "en" => "Delete Item",
          "de" => "Element löschen",
          "uk" => "Видалити елемент"
        })
    }
  end

  def status_messages do
    gettext_mapper(%{
      "en" => "Processing your request",
      "de" => "Verarbeite deine Anfrage",
      "uk" => "Обробляємо ваш запит"
    })
  end
end
