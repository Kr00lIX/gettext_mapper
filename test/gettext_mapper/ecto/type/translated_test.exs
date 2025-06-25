defmodule GettextMapper.Ecto.Type.TranslatedTest do
  use ExUnit.Case, async: true
  doctest GettextMapper.Ecto.Type.Translated, import: true

  import GettextMapper.Ecto.Type.Translated

  test "expect type is map" do
    assert :map == type()
  end

  describe ".cast" do
    test "expect success cast map" do
      params = %{"en" => "Hello", "nb" => "Hallo", "da" => "Hej"}
      assert {:ok, params} == cast(params)
    end

    test "expect :error for not supported locale" do
      params = %{"en" => "Hello", "klingon" => "nuqneH"}
      assert :error == cast(params)
    end

    test "expect error for invalid data" do
      assert :error == cast("string")
    end
  end

  describe ".load" do
    setup do
      params = %{"en" => "Hello", "nb" => "Hallo", "da" => "Hej"}
      [params: params]
    end

    test "expect return of original map", %{params: params} do
      assert {:ok, params} == load(params)
    end
  end

  describe ".dump" do
    test "expect ok for valid map" do
      params = %{"en" => "Hello", "nb" => "Hallo", "da" => "Hej"}
      assert {:ok, params} == dump(params)
    end

    test "expect returns error for invalid data" do
      assert :error == dump([:a, self(), :c])
    end
  end

  describe "localize/2" do
    test "with nb locale" do
      map = %{"en" => "Hello", "nb" => "Hallo"}
      assert "Hallo" == localize(map, "Default")
    end

    test "fallback to default locale when current not present" do
      map = %{"en" => "Hello"}
      assert "Hello" == localize(map, "Default")
    end

    test "fallback to default" do
      assert "Default" == localize(%{"da" => "Hej"}, "Default")
    end

    test "empty string for nil and default empty" do
      assert "" == localize(nil)
    end
  end

  describe "translate/2" do
    test "gets value by locale" do
      map = %{"en" => "Hello", "nb" => "Hallo"}
      assert "Hallo" == translate(map, "nb")
    end

    test "fallback to default locale" do
      map = %{"en" => "Hello"}
      assert "Hello" == translate(map, "nb")
    end

    test "fallback to NO TRANSLATION" do
      assert "NO TRANSLATION" == translate(%{"da" => "Hej"}, "nb")
    end
  end
end
