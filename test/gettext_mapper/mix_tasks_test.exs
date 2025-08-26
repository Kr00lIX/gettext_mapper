defmodule GettextMapper.MixTasksTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  @test_priv_dir "test_priv_mix_tasks"

  setup do
    # Clean up test directories
    if File.exists?(@test_priv_dir), do: File.rm_rf!(@test_priv_dir)

    on_exit(fn ->
      if File.exists?(@test_priv_dir), do: File.rm_rf!(@test_priv_dir)
    end)
  end

  describe "Mix.Tasks.GettextMapper.Extract" do
    test "run/1 extracts translations from files" do
      test_file = "test_extract_simple.ex"

      File.write!(test_file, """
      defmodule TestExtract do
        use GettextMapper

        def message do
          gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run(["--priv", @test_priv_dir, test_file])
        end)

      assert output =~ "Processed 1 translation maps"
      assert File.exists?(Path.join([@test_priv_dir, "de", "LC_MESSAGES", "default.po"]))
    end

    test "run/1 with dry-run flag" do
      test_file = "test_extract_dry.ex"

      File.write!(test_file, """
      defmodule TestExtractDry do
        use GettextMapper

        def message do
          gettext_mapper(%{"en" => "Test", "de" => "Test"})
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run(["--dry-run", "--priv", @test_priv_dir, test_file])
        end)

      assert output =~ "Running in dry-run mode"
      assert output =~ "Would update"
      refute File.exists?(@test_priv_dir)
    end

    test "run/1 with no files specified uses lib/**/*.ex" do
      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run(["--priv", @test_priv_dir])
        end)

      # Should complete without error
      assert output =~ "translation maps"
    end

    test "run/1 handles domain-specific extractions" do
      test_file = "test_extract_domain.ex"

      File.write!(test_file, """
      defmodule TestExtractDomain do
        use GettextMapper, domain: "admin"

        def message do
          gettext_mapper(%{"en" => "Admin", "de" => "Verwaltung"})
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      capture_io(fn ->
        Mix.Tasks.GettextMapper.Extract.run(["--priv", @test_priv_dir, test_file])
      end)

      assert File.exists?(Path.join([@test_priv_dir, "de", "LC_MESSAGES", "admin.po"]))
    end

    test "run/1 handles files with no translation maps" do
      test_file = "test_extract_empty.ex"

      File.write!(test_file, """
      defmodule TestExtractEmpty do
        def message, do: "Hello"
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run(["--priv", @test_priv_dir, test_file])
        end)

      assert output =~ "No static translation maps found"
    end

    test "run/1 with backend option" do
      test_file = "test_extract_backend.ex"

      File.write!(test_file, """
      defmodule TestExtractBackend do
        use GettextMapper

        def message do
          gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run([
            "--backend",
            "MyGettextApp",
            "--priv",
            @test_priv_dir,
            test_file
          ])
        end)

      assert output =~ "Processed"
    end
  end

  describe "Mix.Tasks.GettextMapper.Sync" do
    test "run/1 syncs translation maps with .po files" do
      # Temporarily modify the existing gettext files to add a new test translation
      de_po_path = "test/priv/gettext/de/LC_MESSAGES/default.po"
      original_content = File.read!(de_po_path)

      # Add our test message temporarily  
      test_content =
        original_content <>
          """

          msgid "Welcome"
          msgstr "Willkommen zurück"
          """

      File.write!(de_po_path, test_content)

      # Clean up: restore original content on exit
      on_exit(fn -> File.write!(de_po_path, original_content) end)

      test_file = "test_sync_simple.ex"

      File.write!(test_file, """
      defmodule TestSync do
        use GettextMapper

        def message do
          gettext_mapper(%{"en" => "Welcome", "de" => "Willkommen"})
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      # Mock the backend configuration for this test
      Application.put_env(:gettext_mapper, :gettext, MyGettextApp)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run([test_file])
        end)

      assert output =~ "Processed 1 files"

      # Should have updated the file with the translation from .po file
      updated_content = File.read!(test_file)
      assert updated_content =~ "Willkommen zurück"
    end

    test "run/1 with dry-run flag" do
      test_file = "test_sync_dry.ex"

      File.write!(test_file, """
      defmodule TestSyncDry do
        use GettextMapper

        def message do
          gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run(["--dry-run", test_file])
        end)

      assert output =~ "Running in dry-run mode"
    end

    test "run/1 with message option generates translation map" do
      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run(["--message", "Hello World"])
        end)

      assert output =~ "Original message: \"Hello World\""
      assert output =~ "Updated translation map:"
    end

    test "run/1 with no files specified uses lib/**/*.ex" do
      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run([])
        end)

      # Should complete without error
      assert output =~ "Processed"
    end

    test "run/1 handles invalid backend configuration" do
      # Temporarily remove backend configuration
      old_config = Application.get_env(:gettext_mapper, :gettext)
      Application.delete_env(:gettext_mapper, :gettext)

      on_exit(fn ->
        if old_config do
          Application.put_env(:gettext_mapper, :gettext, old_config)
        end
      end)

      assert_raise RuntimeError, ~r/expects :gettext to be configured/, fn ->
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run(["--message", "Test"])
        end)
      end
    end

    test "run/1 with backend option" do
      test_file = "test_sync_backend.ex"

      File.write!(test_file, """
      defmodule TestSyncBackend do
        use GettextMapper

        def message do
          gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run(["--backend", "MyGettextApp", test_file])
        end)

      assert output =~ "Processed"
    end

    test "handles files with parsing errors gracefully" do
      test_file = "test_sync_error.ex"

      File.write!(test_file, """
      defmodule TestSyncError do
        use GettextMapper

        def message do
          gettext_mapper(%{"en" => "Hello", invalid_syntax
        end
      end
      """)

      on_exit(fn -> File.rm(test_file) end)

      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run([test_file])
        end)

      # Should handle errors gracefully
      assert output =~ "Processed"
    end
  end

  describe "error handling" do
    test "extract task handles non-existent files" do
      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Extract.run(["non_existent_file.ex"])
        end)

      # Should handle gracefully
      assert output =~ "translation maps"
    end

    test "sync task handles non-existent files" do
      output =
        capture_io(fn ->
          Mix.Tasks.GettextMapper.Sync.run(["non_existent_file.ex"])
        end)

      # Should handle gracefully
      assert output =~ "Processed"
    end
  end
end
