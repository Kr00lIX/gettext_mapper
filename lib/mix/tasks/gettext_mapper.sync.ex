defmodule Mix.Tasks.GettextMapper.Sync do
  @shortdoc "Synchronize gettext translations with static translation maps in code"

  @moduledoc """
  Synchronizes gettext translations with static translation maps in your Elixir code.

  This task scans your codebase for `gettext_mapper/1` calls with static maps and
  updates them with the latest translations from your gettext .po files.

  ## Examples

      # Sync all files in lib/
      mix gettext_mapper.sync

      # Sync specific files
      mix gettext_mapper.sync lib/my_app/models.ex lib/my_app/views.ex

      # Dry run (show what would be changed without modifying files)
      mix gettext_mapper.sync --dry-run

      # Use specific backend
      mix gettext_mapper.sync --backend MyApp.Gettext

      # Generate translation map for a specific message (doesn't modify files)
      mix gettext_mapper.sync --message "Hello"

  ## How it works

  1. Finds all `gettext_mapper(%{...})` calls with static translation maps
  2. Extracts the msgid to look up (custom msgid if specified, otherwise default locale message)
  3. Looks up current translations for that msgid in gettext .po files
  4. Updates the static map with the current translations
  5. Applies Elixir's built-in formatter to ensure consistent, idiomatic formatting

  ## Custom Message IDs

  The task supports the `msgid` option for stable translation keys:

      # This call uses "greeting.hello" as the msgid for .po file lookup
      gettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, msgid: "greeting.hello")

  When syncing, the task will:
  - Look up translations for "greeting.hello" in .po files
  - Update the map values with found translations
  - Preserve the `msgid` option in the output

  This allows you to change the displayed text while keeping the same translation key.

  ## Formatting

  The task automatically formats the updated translation maps using Elixir's built-in
  `Code.format_string!/2` function, ensuring that the output follows your project's
  formatting conventions.
  """

  use Mix.Task

  alias GettextMapper.CodeParser
  alias GettextMapper.GettextAPI

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("compile")
    Mix.Task.run("app.start")

    {opts, paths, _} =
      OptionParser.parse(args,
        switches: [dry_run: :boolean, backend: :string, message: :string],
        aliases: [d: :dry_run, b: :backend, m: :message]
      )

    dry_run = Keyword.get(opts, :dry_run, false)
    backend = GettextAPI.get_backend(opts)
    message = Keyword.get(opts, :message)

    # If message is provided, just generate the translation map
    if message do
      generate_single_translation_map(message, backend)
    else
      # Sync files
      files_to_process =
        if Enum.empty?(paths) do
          find_elixir_files()
        else
          paths
        end

      if dry_run do
        Mix.shell().info("Running in dry-run mode. No files will be modified.")
      end

      total_files = length(files_to_process)

      updated_count =
        Enum.reduce(files_to_process, 0, fn file, acc ->
          if process_file(file, backend, dry_run) do
            acc + 1
          else
            acc
          end
        end)

      Mix.shell().info(
        "Processed #{total_files} files, updated #{updated_count} files with translation changes."
      )
    end
  end

  defp generate_single_translation_map(message, backend) do
    try do
      default_domain = GettextAPI.default_domain()
      translation_map = generate_translation_map(message, backend, default_domain)

      Mix.shell().info("Original message: \"#{message}\"")
      Mix.shell().info("Updated translation map:")
      Mix.shell().info(format_elixir_map(translation_map))
    rescue
      error ->
        Mix.shell().error("Error: #{Exception.message(error)}")
    end
  end

  defp find_elixir_files do
    "lib/**/*.ex"
    |> Path.wildcard()
    |> Enum.filter(&File.exists?/1)
  end

  defp process_file(file_path, backend, dry_run) do
    content = File.read!(file_path)
    updated_content = sync_translation_maps(content, backend)

    if content != updated_content do
      if dry_run do
        Mix.shell().info("Would update: #{file_path}")
        show_diff(content, updated_content)
      else
        File.write!(file_path, updated_content)
        Mix.shell().info("Updated: #{file_path}")
      end

      true
    else
      false
    end
  rescue
    error ->
      Mix.shell().error("Error processing #{file_path}: #{Exception.message(error)}")
      false
  end

  defp sync_translation_maps(content, backend) do
    # Use AST-based parsing to find all gettext_mapper calls
    calls = CodeParser.find_gettext_mapper_calls(content)

    # Process each call and replace in content
    Enum.reduce(calls, content, fn call_info, acc ->
      process_call(call_info, acc, backend)
    end)
  end

  defp process_call(call_info, content, backend) do
    %{
      translations: translations,
      domain: domain,
      msgid: custom_msgid,
      raw_match: raw_match
    } = call_info

    # Skip if we couldn't extract the raw match
    if is_nil(raw_match) do
      content
    else
      # Determine domain to use
      effective_domain = domain || GettextAPI.default_domain()

      # Determine which msgid to use for lookup
      default_locale = GettextAPI.default_locale_for(backend)
      default_message = Map.get(translations, default_locale)
      lookup_msgid = custom_msgid || default_message || Map.get(translations, "en")

      if lookup_msgid do
        # Generate updated translations from .po files
        updated_translations = generate_translation_map(lookup_msgid, backend, effective_domain)

        # Format the replacement call
        replacement = CodeParser.format_gettext_mapper_call(
          updated_translations,
          domain,
          custom_msgid
        )

        # Replace in content
        String.replace(content, raw_match, replacement, global: false)
      else
        content
      end
    end
  end

  defp generate_translation_map(message, backend, domain) do
    # Discover locales from .po files and read translations directly
    known_locales = discover_locales_from_po_files(backend, domain)

    Enum.into(known_locales, %{}, fn locale ->
      translation = lookup_translation_in_po(backend, locale, domain, message)
      {locale, translation}
    end)
  end

  defp lookup_translation_in_po(backend, locale, domain, message) do
    priv_dir = GettextAPI.priv_dir(backend)
    default_domain = GettextAPI.default_domain()
    po_filename = if domain == default_domain, do: "#{default_domain}.po", else: "#{domain}.po"
    po_file_path = Path.join([priv_dir, locale, "LC_MESSAGES", po_filename])

    if File.exists?(po_file_path) do
      content = File.read!(po_file_path)
      extract_translation_from_po_content(content, message)
    else
      # Fall back to original message if no .po file
      message
    end
  end

  defp extract_translation_from_po_content(content, msgid) do
    # Look for the msgid and extract the corresponding msgstr
    escaped_msgid = Regex.escape(msgid)
    pattern = ~r/msgid "#{escaped_msgid}"\s*\nmsgstr "([^"]*)"/s

    case Regex.run(pattern, content) do
      [_, msgstr] -> msgstr
      # Fall back to msgid if not found
      _ -> msgid
    end
  end

  defp discover_locales_from_po_files(backend, domain) do
    priv_dir = GettextAPI.priv_dir(backend)
    default_domain = GettextAPI.default_domain()
    po_filename = if domain == default_domain, do: "#{default_domain}.po", else: "#{domain}.po"

    # Look for locale directories with the domain .po file
    if File.exists?(priv_dir) do
      priv_dir
      |> File.ls!()
      |> Enum.filter(fn item ->
        locale_dir = Path.join(priv_dir, item)
        po_file = Path.join([locale_dir, "LC_MESSAGES", po_filename])
        File.dir?(locale_dir) && File.exists?(po_file)
      end)
    else
      # Fallback to default if no priv dir exists
      [GettextAPI.default_locale()]
    end
  end

  defp format_elixir_map(map) do
    entries =
      map
      |> Enum.sort_by(fn {locale, _} -> locale end)
      |> Enum.map(fn {locale, translation} ->
        ~s("#{locale}" => "#{CodeParser.escape_string(translation)}")
      end)

    "%{#{Enum.join(entries, ", ")}}"
  end

  defp show_diff(original, updated) do
    # Simple diff display - shows only changed lines
    original_lines = String.split(original, "\n")
    updated_lines = String.split(updated, "\n")

    Enum.with_index(original_lines)
    |> Enum.each(fn {line, index} ->
      updated_line = Enum.at(updated_lines, index, "")

      if line != updated_line do
        Mix.shell().info("  - #{line}")
        Mix.shell().info("  + #{updated_line}")
      end
    end)
  end
end
