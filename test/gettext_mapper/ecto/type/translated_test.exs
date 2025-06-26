defmodule GettextMapper.Ecto.Type.TranslatedTest do
  use ExUnit.Case, async: true
  doctest GettextMapper.Ecto.Type.Translated, import: true

  import GettextMapper.Ecto.Type.Translated

  test "expect type is map" do
    assert :map == type()
  end

  describe ".cast" do
    test "expect success cast map" do
      params = %{"en" => "Hello", "de" => "Hallo", "uk" => "Привіт"}
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

  describe ".localize/2 and .translate/2 have been moved to GettextMapper module" do
    test "module no longer defines localize/2 or translate/2" do
      refute function_exported?(GettextMapper.Ecto.Type.Translated, :localize, 2)
      refute function_exported?(GettextMapper.Ecto.Type.Translated, :translate, 2)
    end
  end
end
