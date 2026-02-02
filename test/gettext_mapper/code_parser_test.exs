defmodule GettextMapper.CodeParserTest do
  use ExUnit.Case, async: true

  doctest GettextMapper.CodeParser

  alias GettextMapper.CodeParser

  describe "find_gettext_mapper_calls/1" do
    test "finds simple gettext_mapper call" do
      content = ~s|gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello", "de" => "Hallo"}
      assert call.domain == nil
      assert call.msgid == nil
      assert call.line == 1
      assert call.macro == :gettext_mapper
    end

    test "finds gettext_mapper call with domain option" do
      content = ~s|gettext_mapper(%{"en" => "Hello"}, domain: "admin")|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello"}
      assert call.domain == "admin"
    end

    test "finds gettext_mapper call with msgid option" do
      content = ~s|gettext_mapper(%{"en" => "Hello"}, msgid: "greeting.hello")|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello"}
      assert call.msgid == "greeting.hello"
    end

    test "finds gettext_mapper call with both domain and msgid options" do
      content = ~s|gettext_mapper(%{"en" => "Hello"}, domain: "admin", msgid: "greeting")|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello"}
      assert call.domain == "admin"
      assert call.msgid == "greeting"
    end

    test "finds lgettext_mapper call" do
      content = ~s|lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"})|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello", "de" => "Hallo"}
      assert call.macro == :lgettext_mapper
    end

    test "finds lgettext_mapper call with locale option" do
      content = ~s|lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, locale: "de")|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello", "de" => "Hallo"}
    end

    test "finds lgettext_mapper call with default option" do
      content = ~s|lgettext_mapper(%{"en" => "Hello"}, default: "No translation")|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello"}
    end

    test "finds multiple calls in content" do
      content = """
      defmodule Test do
        def greeting, do: gettext_mapper(%{"en" => "Hello"})
        def farewell, do: gettext_mapper(%{"en" => "Goodbye"})
      end
      """

      calls = CodeParser.find_gettext_mapper_calls(content)

      assert length(calls) == 2
      translations = Enum.map(calls, & &1.translations)
      assert %{"en" => "Hello"} in translations
      assert %{"en" => "Goodbye"} in translations
    end

    test "extracts module-level domain" do
      content = """
      defmodule Test do
        use GettextMapper, domain: "admin"

        def greeting, do: gettext_mapper(%{"en" => "Hello"})
      end
      """

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.domain == "admin"
    end

    test "call-level domain overrides module-level domain" do
      content = """
      defmodule Test do
        use GettextMapper, domain: "admin"

        def greeting, do: gettext_mapper(%{"en" => "Hello"}, domain: "custom")
      end
      """

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.domain == "custom"
    end

    test "returns empty list for invalid content" do
      content = "this is not valid {{ elixir code"

      assert CodeParser.find_gettext_mapper_calls(content) == []
    end

    test "returns empty list for content without gettext_mapper calls" do
      content = """
      defmodule Test do
        def hello, do: "Hello"
      end
      """

      assert CodeParser.find_gettext_mapper_calls(content) == []
    end

    test "handles multiline map" do
      content = """
      gettext_mapper(%{
        "en" => "Hello",
        "de" => "Hallo",
        "uk" => "Привіт"
      })
      """

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.translations == %{"en" => "Hello", "de" => "Hallo", "uk" => "Привіт"}
    end

    test "extracts raw_match for replacement" do
      content = ~s|gettext_mapper(%{"en" => "Hello"})|

      [call] = CodeParser.find_gettext_mapper_calls(content)

      assert call.raw_match != nil
      assert String.contains?(call.raw_match, "gettext_mapper")
    end
  end

  describe "extract_module_domain/1" do
    test "extracts domain from use GettextMapper" do
      content = ~s|use GettextMapper, domain: "admin"|

      assert CodeParser.extract_module_domain(content) == "admin"
    end

    test "returns nil when no domain specified" do
      content = "use GettextMapper"

      assert CodeParser.extract_module_domain(content) == nil
    end

    test "returns nil for invalid content" do
      content = "invalid {{ code"

      assert CodeParser.extract_module_domain(content) == nil
    end

    test "returns nil when GettextMapper not used" do
      content = """
      defmodule Test do
        def hello, do: "Hello"
      end
      """

      assert CodeParser.extract_module_domain(content) == nil
    end

    test "extracts domain from full module" do
      content = """
      defmodule MyApp.Admin do
        use GettextMapper, domain: "admin"

        def title do
          gettext_mapper(%{"en" => "Admin Panel"})
        end
      end
      """

      assert CodeParser.extract_module_domain(content) == "admin"
    end
  end

  describe "parse_translation_map/1" do
    test "parses simple map string" do
      map_string = ~s|"en" => "Hello", "de" => "Hallo"|

      assert {:ok, translations} = CodeParser.parse_translation_map(map_string)
      assert translations == %{"en" => "Hello", "de" => "Hallo"}
    end

    test "parses single entry" do
      map_string = ~s|"en" => "Hello"|

      assert {:ok, translations} = CodeParser.parse_translation_map(map_string)
      assert translations == %{"en" => "Hello"}
    end

    test "returns error for invalid map string" do
      assert CodeParser.parse_translation_map("invalid") == :error
    end

    test "returns error for empty map" do
      assert CodeParser.parse_translation_map("") == :error
    end

    test "returns error for map with non-string keys" do
      map_string = ~s|:en => "Hello"|

      assert CodeParser.parse_translation_map(map_string) == :error
    end

    test "returns error for map with non-string values" do
      map_string = ~s|"en" => 123|

      assert CodeParser.parse_translation_map(map_string) == :error
    end

    test "handles escaped quotes in values" do
      map_string = ~s|"en" => "Hello \\"World\\""|

      assert {:ok, translations} = CodeParser.parse_translation_map(map_string)
      assert translations["en"] == ~s|Hello "World"|
    end

    test "handles unicode characters" do
      map_string = ~s|"uk" => "Привіт"|

      assert {:ok, translations} = CodeParser.parse_translation_map(map_string)
      assert translations["uk"] == "Привіт"
    end
  end

  describe "escape_string/1" do
    test "escapes backslashes" do
      assert CodeParser.escape_string("hello\\world") == "hello\\\\world"
    end

    test "escapes double quotes" do
      assert CodeParser.escape_string(~s|hello "world"|) == ~s|hello \\"world\\"|
    end

    test "escapes both backslashes and quotes" do
      assert CodeParser.escape_string(~s|path\\to\\"file"|) == ~s|path\\\\to\\\\\\"file\\"|
    end

    test "returns unchanged string with no special characters" do
      assert CodeParser.escape_string("hello world") == "hello world"
    end

    test "handles empty string" do
      assert CodeParser.escape_string("") == ""
    end

    test "handles unicode" do
      assert CodeParser.escape_string("Привіт") == "Привіт"
    end
  end

  describe "format_gettext_mapper_call/3" do
    test "formats simple call without options" do
      translations = %{"en" => "Hello", "de" => "Hallo"}

      result = CodeParser.format_gettext_mapper_call(translations, nil, nil)

      assert String.contains?(result, "gettext_mapper")
      assert String.contains?(result, "Hello")
      assert String.contains?(result, "Hallo")
    end

    test "formats call with domain option" do
      translations = %{"en" => "Hello"}

      result = CodeParser.format_gettext_mapper_call(translations, "admin", nil)

      assert String.contains?(result, "domain:")
      assert String.contains?(result, "admin")
    end

    test "formats call with msgid option" do
      translations = %{"en" => "Hello"}

      result = CodeParser.format_gettext_mapper_call(translations, nil, "greeting.hello")

      assert String.contains?(result, "msgid:")
      assert String.contains?(result, "greeting.hello")
    end

    test "formats call with both domain and msgid options" do
      translations = %{"en" => "Hello"}

      result = CodeParser.format_gettext_mapper_call(translations, "admin", "greeting.hello")

      assert String.contains?(result, "domain:")
      assert String.contains?(result, "msgid:")
    end

    test "sorts translations by locale" do
      translations = %{"uk" => "Привіт", "de" => "Hallo", "en" => "Hello"}

      result = CodeParser.format_gettext_mapper_call(translations, nil, nil)

      # de should come before en which should come before uk
      de_pos = :binary.match(result, "de")
      en_pos = :binary.match(result, "en")
      uk_pos = :binary.match(result, "uk")

      assert de_pos < en_pos
      assert en_pos < uk_pos
    end

    test "escapes special characters in translations" do
      translations = %{"en" => ~s|Hello "World"|}

      result = CodeParser.format_gettext_mapper_call(translations, nil, nil)

      assert String.contains?(result, ~s|\\"|)
    end

    test "does not include default domain in output" do
      translations = %{"en" => "Hello"}

      result = CodeParser.format_gettext_mapper_call(translations, "default", nil)

      refute String.contains?(result, "domain:")
    end

    test "formats lgettext_mapper call when macro_name is :lgettext_mapper" do
      translations = %{"en" => "Hello", "de" => "Hallo"}

      result = CodeParser.format_gettext_mapper_call(translations, nil, nil, :lgettext_mapper)

      assert String.starts_with?(result, "lgettext_mapper")
      refute String.starts_with?(result, "gettext_mapper")
    end

    test "formats gettext_mapper call by default" do
      translations = %{"en" => "Hello"}

      result = CodeParser.format_gettext_mapper_call(translations, nil, nil)

      assert String.starts_with?(result, "gettext_mapper")
    end
  end

  describe "extract_call_source/2" do
    test "extracts single line call" do
      content = ~s|gettext_mapper(%{"en" => "Hello"})|

      result = CodeParser.extract_call_source(content, 1)

      assert result == ~s|gettext_mapper(%{"en" => "Hello"})|
    end

    test "extracts multiline call" do
      content = """
      gettext_mapper(%{
        "en" => "Hello",
        "de" => "Hallo"
      })
      """

      result = CodeParser.extract_call_source(content, 1)

      assert result != nil
      assert String.contains?(result, "gettext_mapper")
      assert String.contains?(result, "Hello")
      assert String.contains?(result, "Hallo")
    end

    test "returns nil for invalid line number (negative)" do
      content = ~s|gettext_mapper(%{"en" => "Hello"})|

      assert CodeParser.extract_call_source(content, -1) == nil
    end

    test "returns nil for line number beyond content" do
      content = ~s|gettext_mapper(%{"en" => "Hello"})|

      assert CodeParser.extract_call_source(content, 100) == nil
    end

    test "extracts lgettext_mapper call" do
      content = ~s|lgettext_mapper(%{"en" => "Hello"})|

      result = CodeParser.extract_call_source(content, 1)

      assert result != nil
      assert String.contains?(result, "lgettext_mapper")
      assert String.contains?(result, "Hello")
    end

    test "handles call with options" do
      content = ~s|gettext_mapper(%{"en" => "Hello"}, domain: "admin", msgid: "greeting")|

      result = CodeParser.extract_call_source(content, 1)

      assert String.contains?(result, "domain:")
      assert String.contains?(result, "msgid:")
    end
  end
end
