defmodule GettextMapperTest do
  use ExUnit.Case, async: true

  describe "localize/2" do
    test "returns current locale value when present" do
      map = %{"en" => "Hello", "nb" => "Hallo"}
      assert GettextMapper.localize(map, "Default") == "Hallo"
    end

    test "falls back to default locale when current missing" do
      map = %{"en" => "Hello"}
      assert GettextMapper.localize(map, "Default") == "Hello"
    end

    test "falls back to default value when no locale matches" do
      map = %{"da" => "Hej"}
      assert GettextMapper.localize(map, "Default") == "Default"
    end

    test "returns empty string when value is nil and default empty" do
      assert GettextMapper.localize(nil) == ""
    end
  end

  describe "translate/2" do
    test "returns value for given locale" do
      map = %{"en" => "Hello", "nb" => "Hallo"}
      assert GettextMapper.translate(map, "nb") == "Hallo"
    end

    test "falls back to default locale when locale missing" do
      map = %{"en" => "Hello"}
      assert GettextMapper.translate(map, "nb") == "Hello"
    end

    test "returns NO TRANSLATION when no locale matches" do
      map = %{"da" => "Hej"}
      assert GettextMapper.translate(map, "nb") == "NO TRANSLATION"
    end
  end
end
