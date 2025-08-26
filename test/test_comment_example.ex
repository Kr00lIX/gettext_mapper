defmodule TestCommentExample do
  @moduledoc """
  This is a module with documentation.

  Example usage:

      gettext_mapper(%{"en" => "Doc Example", "de" => "Dok Beispiel"})

  This should be ignored in documentation.
  """

  use GettextMapper

  @doc """
  A function with documentation that contains:

      gettext_mapper(%{"en" => "Function Doc", "de" => "Funktion Dok"})

  This should also be ignored.
  """
  def valid_call do
    gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
  end

  # This should be ignored: gettext_mapper(%{"en" => "Ignored", "de" => "Ignoriert"})

  def another_valid_call do
    # Comment before valid call
    gettext_mapper(%{"en" => "World", "de" => "Welt"})
  end
end
