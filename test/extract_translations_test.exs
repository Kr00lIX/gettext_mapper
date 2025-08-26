defmodule ExtractTranslationsTest do
  use ExUnit.Case, async: false

  @test_priv_dir "test_priv_extract"
  @test_files ["test/sync_integration/user_module.ex", "test/sync_integration/product_module.ex"]

  setup do
    # Clean up test directory
    if File.exists?(@test_priv_dir), do: File.rm_rf!(@test_priv_dir)

    on_exit(fn ->
      if File.exists?(@test_priv_dir), do: File.rm_rf!(@test_priv_dir)
    end)
  end

  describe "mix gettext_mapper.extract" do
    test "extracts both msgids and translations from static maps" do
      # Run extraction to custom priv directory
      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "gettext_mapper.extract",
            "--priv",
            @test_priv_dir
          ] ++ @test_files,
          env: [{"MIX_ENV", "test"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0, "Extraction failed: #{output}"
      assert output =~ "Processed", "Should report processing results"

      # Verify German .po file was created and populated
      de_po_path = Path.join([@test_priv_dir, "de", "LC_MESSAGES", "default.po"])
      assert File.exists?(de_po_path), "German .po file should be created"

      de_content = File.read!(de_po_path)
      assert de_content =~ "msgid \"Hello!\"", "Should contain msgid"
      assert de_content =~ "msgstr \"Hallo!\"", "Should contain German translation"
      assert de_content =~ "msgid \"Welcome!\"", "Should contain Welcome msgid"
      assert de_content =~ "msgstr \"Willkommen!\"", "Should contain German Welcome translation"

      # Verify Ukrainian .po file was created and populated
      uk_po_path = Path.join([@test_priv_dir, "uk", "LC_MESSAGES", "default.po"])
      assert File.exists?(uk_po_path), "Ukrainian .po file should be created"

      uk_content = File.read!(uk_po_path)
      assert uk_content =~ "msgid \"Hello!\"", "Should contain msgid"
      assert uk_content =~ "msgstr \"Привіт!\"", "Should contain Ukrainian translation"
      assert uk_content =~ "msgid \"Welcome!\"", "Should contain Welcome msgid"

      assert uk_content =~ "msgstr \"Ласкаво просимо!\"",
             "Should contain Ukrainian Welcome translation"
    end

    test "dry run shows what would be extracted without creating files" do
      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "gettext_mapper.extract",
            "--dry-run",
            "--priv",
            @test_priv_dir
          ] ++ @test_files,
          env: [{"MIX_ENV", "test"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0
      assert output =~ "Running in dry-run mode"
      assert output =~ "Would update"
      assert output =~ "msgid \"Hello!\" -> msgstr \"Hallo!\""

      # Verify no files were actually created
      refute File.exists?(@test_priv_dir), "Should not create files in dry-run mode"
    end

    test "handles files with no gettext_mapper calls gracefully" do
      # Create a temporary file without gettext_mapper calls
      temp_file = "test_no_maps.ex"

      File.write!(temp_file, """
      defmodule NoMaps do
        def hello, do: "Hello"
      end
      """)

      on_exit(fn -> File.rm(temp_file) end)

      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "gettext_mapper.extract",
            "--priv",
            @test_priv_dir,
            temp_file
          ],
          env: [{"MIX_ENV", "test"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0
      assert output =~ "No static translation maps found"
    end

    test "updates existing .po files without duplicating entries" do
      # First extraction
      System.cmd(
        "mix",
        [
          "gettext_mapper.extract",
          "--priv",
          @test_priv_dir
        ] ++ @test_files,
        env: [{"MIX_ENV", "test"}]
      )

      # Read initial content
      de_po_path = Path.join([@test_priv_dir, "de", "LC_MESSAGES", "default.po"])
      initial_content = File.read!(de_po_path)
      initial_hello_count = length(Regex.scan(~r/msgid "Hello!"/, initial_content))

      # Second extraction (should update, not duplicate)
      System.cmd(
        "mix",
        [
          "gettext_mapper.extract",
          "--priv",
          @test_priv_dir
        ] ++ @test_files,
        env: [{"MIX_ENV", "test"}]
      )

      # Verify no duplication
      updated_content = File.read!(de_po_path)
      updated_hello_count = length(Regex.scan(~r/msgid "Hello!"/, updated_content))

      assert initial_hello_count == updated_hello_count, "Should not duplicate entries"
      assert updated_content =~ "msgstr \"Hallo!\"", "Should maintain translation"
    end

    test "extracts additional static maps correctly" do
      # Create test file with additional static maps
      additional_file = "test_additional.ex"

      File.write!(additional_file, """
      defmodule AdditionalMaps do
        use Gettext, backend: MyGettextApp
        use GettextMapper

        def error_message do
          gettext_mapper(%{
            "en" => "Something went wrong",
            "de" => "Etwas ist schief gelaufen",
            "uk" => "Щось пішло не так"
          })
        end
      end
      """)

      on_exit(fn -> File.rm(additional_file) end)

      {_output, exit_code} =
        System.cmd(
          "mix",
          [
            "gettext_mapper.extract",
            "--priv",
            @test_priv_dir,
            additional_file
          ],
          env: [{"MIX_ENV", "test"}],
          stderr_to_stdout: true
        )

      assert exit_code == 0

      # Verify additional translations are extracted
      de_po_path = Path.join([@test_priv_dir, "de", "LC_MESSAGES", "default.po"])
      de_content = File.read!(de_po_path)
      assert de_content =~ "msgid \"Something went wrong\"", "Should contain error message msgid"

      assert de_content =~ "msgstr \"Etwas ist schief gelaufen\"",
             "Should contain German error translation"
    end
  end

  describe "integration with gettext workflow" do
    test "extracted .po files work with standard gettext commands" do
      # Extract translations
      System.cmd(
        "mix",
        [
          "gettext_mapper.extract",
          "--priv",
          @test_priv_dir
        ] ++ @test_files,
        env: [{"MIX_ENV", "test"}]
      )

      # Verify we can merge with gettext
      {output, exit_code} =
        System.cmd(
          "mix",
          [
            "gettext.merge",
            @test_priv_dir
          ],
          env: [{"MIX_ENV", "test"}],
          stderr_to_stdout: true
        )

      # Should complete successfully (even if no new messages to merge)
      assert exit_code == 0, "Gettext merge should work with extracted files: #{output}"
    end
  end
end
