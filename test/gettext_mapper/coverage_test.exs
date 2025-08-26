defmodule GettextMapper.CoverageTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  describe "error handling and edge cases" do
    test "GettextMapper.localize with nil and defaults" do
      assert GettextMapper.localize(nil, "default") == ""
      assert GettextMapper.localize(nil) == ""
    end

    test "GettextMapper.translate with edge cases" do
      # Test with map that doesn't have the requested locale
      map = %{"en" => "Hello", "de" => "Hallo"}
      # Falls back to default locale
      assert GettextMapper.translate(map, "es") == "Hello"

      # Test with empty map
      assert GettextMapper.translate(%{}, "en") == "NO TRANSLATION"
    end

    test "default_translation configuration" do
      # Test with custom default translation
      original_config = Application.get_env(:gettext_mapper, :default_translation)
      Application.put_env(:gettext_mapper, :default_translation, "MISSING")

      assert GettextMapper.translate(%{}, "en") == "MISSING"

      # Restore original config
      if original_config do
        Application.put_env(:gettext_mapper, :default_translation, original_config)
      else
        Application.delete_env(:gettext_mapper, :default_translation)
      end
    end

    test "macros handle gettext calls for extraction" do
      # Test that the macro properly handles gettext function calls
      defmodule TestGettextCalls do
        use GettextMapper

        def dynamic_message do
          # This should work with actual gettext calls too
          message = "Hello"
          gettext_mapper(%{"en" => message, "de" => "Hallo", "uk" => "Привіт"})
        end
      end

      result = TestGettextCalls.dynamic_message()
      assert result["en"] == "Hello"
    end

    test "Mix task error scenarios" do
      # Test extract task with missing backend
      old_config = Application.get_env(:gettext_mapper, :gettext)
      Application.delete_env(:gettext_mapper, :gettext)

      capture_io(fn ->
        assert_raise RuntimeError, fn ->
          Mix.Tasks.GettextMapper.Extract.run(["--message", "test"])
        end
      end)

      # Restore config
      if old_config do
        Application.put_env(:gettext_mapper, :gettext, old_config)
      end
    end

    test "extract task with parsing errors" do
      test_file = "test_parse_error.ex"

      File.write!(test_file, """
      defmodule InvalidSyntax do
        def broken do
          gettext_mapper(%{"en" => "test" missing_brace
        end
      end
      """)

      on_exit(fn -> File.rm_rf(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run([test_file])
        end)

      # Should handle errors gracefully
      assert output =~ "translation maps"
    end

    test "sync task formatting edge cases" do
      test_file = "test_formatting_edge.ex"

      File.write!(test_file, """
      defmodule FormattingEdge do
        use GettextMapper

        def weird_formatting do
          gettext_mapper(
            %{
              "en"    =>    "Hello",
              "de"  =>  "Hallo",
              "uk" => "Привіт"
            }
          )
        end
      end
      """)

      on_exit(fn -> File.rm_rf(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run(["--dry-run", test_file])
        end)

      # Should handle and format correctly
      assert output =~ "Running in dry-run mode"
    end

    test "extract task handles empty directories" do
      empty_dir = "empty_test_dir"
      File.mkdir_p!(empty_dir)

      on_exit(fn -> File.rm_rf!(empty_dir) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run([empty_dir])
        end)

      assert output =~ "translation maps"
    end

    test "macros validation with edge case locales" do
      # Test validation edge cases
      valid_map = %{"en" => "test", "de" => "test", "uk" => "тест"}
      assert :ok = GettextMapper.Macros.validate_translation_map!(valid_map, ["en", "de", "uk"])

      # Test with exact match
      exact_map = %{"en" => "test"}
      assert :ok = GettextMapper.Macros.validate_translation_map!(exact_map, ["en"])
    end

    test "gettext_mapper handles runtime validation errors gracefully" do
      defmodule TestRuntimeValidation do
        use GettextMapper

        def test_invalid_runtime(map) do
          gettext_mapper(map)
        end
      end

      # Should raise proper error for non-map
      assert_raise ArgumentError,
                   ~r/expects either a gettext function call or a translation map/,
                   fn ->
                     TestRuntimeValidation.test_invalid_runtime("not a map")
                   end
    end
  end
end
