defmodule DomainModule do
  use Gettext, backend: MyGettextApp
  use GettextMapper, domain: "product_fixture"

  def product_name do
    gettext_mapper(%{"de" => "Produkt", "en" => "Product", "uk" => "Продукт"})
  end

  def admin_greeting do
    gettext_mapper(%{"de" => "Admin-Bereich", "en" => "Admin Area", "uk" => "Адмін область"},
      domain: "admin"
    )
  end

  def default_greeting do
    gettext_mapper(%{"de" => "Willkommen", "en" => "Welcome", "uk" => "Ласкаво просимо"})
  end
end
