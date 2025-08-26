defmodule DomainExtractionTest do
  use ExUnit.Case, async: false

  @test_priv_dir "test_priv_domain_extract"

  setup do
    # Clean up test directory
    if File.exists?(@test_priv_dir), do: File.rm_rf!(@test_priv_dir)

    on_exit(fn ->
      if File.exists?(@test_priv_dir), do: File.rm_rf!(@test_priv_dir)
    end)
  end

  test "extracts translations to domain-specific .po files" do
    # Create test file with domain-specific gettext_mapper calls
    test_file = "test_domain_extraction.ex"

    File.write!(test_file, """
    defmodule TestDomainModule do
      use Gettext, backend: MyGettextApp
      use GettextMapper, domain: "product"

      def product_name do
        gettext_mapper(%{"en" => "Product", "de" => "Produkt", "uk" => "Продукт"})
      end

      def admin_message do
        gettext_mapper(%{"en" => "Admin Panel", "de" => "Admin-Bereich", "uk" => "Адмін панель"}, domain: "admin")
      end

      def explicit_default_message do
        gettext_mapper(%{"en" => "Default Message", "de" => "Standard Nachricht", "uk" => "Звичайне повідомлення"}, domain: "default")
      end
    end
    """)

    on_exit(fn -> File.rm(test_file) end)

    # Run extraction
    {output, exit_code} =
      System.cmd(
        "mix",
        [
          "gettext_mapper.extract",
          "--priv",
          @test_priv_dir,
          test_file
        ],
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert exit_code == 0, "Extraction failed: #{output}"

    # Verify product domain .po files
    de_product_po = Path.join([@test_priv_dir, "de", "LC_MESSAGES", "product.po"])
    assert File.exists?(de_product_po), "German product.po should be created"

    de_product_content = File.read!(de_product_po)
    assert de_product_content =~ "msgid \"Product\"", "Should contain Product msgid"
    assert de_product_content =~ "msgstr \"Produkt\"", "Should contain German Product translation"

    # Verify admin domain .po files
    de_admin_po = Path.join([@test_priv_dir, "de", "LC_MESSAGES", "admin.po"])
    assert File.exists?(de_admin_po), "German admin.po should be created"

    de_admin_content = File.read!(de_admin_po)
    assert de_admin_content =~ "msgid \"Admin Panel\"", "Should contain Admin Panel msgid"

    assert de_admin_content =~ "msgstr \"Admin-Bereich\"",
           "Should contain German Admin Panel translation"

    # Verify default domain .po files
    de_default_po = Path.join([@test_priv_dir, "de", "LC_MESSAGES", "default.po"])
    assert File.exists?(de_default_po), "German default.po should be created"

    de_default_content = File.read!(de_default_po)

    assert de_default_content =~ "msgid \"Default Message\"",
           "Should contain Default Message msgid"

    assert de_default_content =~ "msgstr \"Standard Nachricht\"",
           "Should contain German Default Message translation"

    # Verify Ukrainian files for completeness
    uk_product_po = Path.join([@test_priv_dir, "uk", "LC_MESSAGES", "product.po"])
    assert File.exists?(uk_product_po), "Ukrainian product.po should be created"

    uk_product_content = File.read!(uk_product_po)

    assert uk_product_content =~ "msgstr \"Продукт\"",
           "Should contain Ukrainian Product translation"
  end

  test "dry run shows domain-specific extraction" do
    test_file = "test_domain_dry_run.ex"

    File.write!(test_file, """
    defmodule TestDomainDryRun do
      use Gettext, backend: MyGettextApp
      use GettextMapper, domain: "product"

      def test_message do
        gettext_mapper(%{"en" => "Test", "de" => "Test", "uk" => "Тест"})
      end
    end
    """)

    on_exit(fn -> File.rm(test_file) end)

    {output, exit_code} =
      System.cmd(
        "mix",
        [
          "gettext_mapper.extract",
          "--dry-run",
          "--priv",
          @test_priv_dir,
          test_file
        ],
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert exit_code == 0
    assert output =~ "Running in dry-run mode"
    assert output =~ "product.po", "Should mention product domain file"
    assert output =~ "msgid \"Test\"", "Should show Test msgid"
    assert output =~ "msgstr \"Тест\"", "Should show Ukrainian translation"

    # Verify no files were actually created
    refute File.exists?(@test_priv_dir), "Should not create files in dry-run mode"
  end
end
