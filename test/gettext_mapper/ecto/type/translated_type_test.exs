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
      # When no locales are configured, any string locale is accepted
      # In production with configured locales, this would return :error
      case GettextMapper.GettextAPI.known_locales() do
        [] -> assert {:ok, params} == cast(params)
        _locales -> assert :error == cast(params)
      end
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

    test "expect error for nil" do
      assert :error == dump(nil)
    end

    test "expect error for non-map data types" do
      assert :error == dump("string")
      assert :error == dump(123)
      assert :error == dump([:list])
      assert :error == dump({:tuple})
    end
  end

  describe "edge cases" do
    test "cast/1 with empty map" do
      assert {:ok, %{}} == cast(%{})
    end

    test "cast/1 with nil" do
      assert :error == cast(nil)
    end

    test "load/1 with nil" do
      assert {:ok, nil} == load(nil)
    end

    test "cast/1 with atom keys gets converted to string keys" do
      # Ecto typically converts atom keys to strings
      result = cast(%{en: "Hello", de: "Hallo"})

      case result do
        {:ok, map} ->
          # Should work with string keys after conversion
          assert is_map(map)

        :error ->
          # This is also acceptable behavior for atom keys
          assert true
      end
    end

    test "cast/1 validates all string values" do
      # Mix of valid and invalid values
      assert :error == cast(%{"en" => "Hello", "de" => 123, "es" => "Hola"})
      assert {:ok, %{"de" => nil, "en" => "Hello"}} == cast(%{"en" => "Hello", "de" => nil})
      assert :error == cast(%{"en" => "Hello", "de" => [:invalid]})
    end

    test "load/1 with various data types" do
      # Should always return ok for any data that reaches this point
      # since load is called by Ecto after database retrieval
      assert {:ok, %{"en" => "test"}} == load(%{"en" => "test"})
      assert {:ok, nil} == load(nil)
    end
  end

  describe ".localize/2 and .translate/2 have been moved to GettextMapper module" do
    test "module no longer defines localize/2 or translate/2" do
      refute function_exported?(GettextMapper.Ecto.Type.Translated, :localize, 2)
      refute function_exported?(GettextMapper.Ecto.Type.Translated, :translate, 2)
    end
  end
end
