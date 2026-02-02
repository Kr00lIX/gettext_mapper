defmodule Mix.Tasks.GettextMapper.Extract do
  @shortdoc "Extract translations from static gettext_mapper maps to populate .po/.pot files"

  @moduledoc """
  Extracts both msgids and translations from static gettext_mapper maps and populates .po/.pot files.

  This task scans your codebase for `gettext_mapper(%{...})` calls with static maps and:
  1. Extracts the msgid (custom msgid if specified, otherwise default locale message)
  2. Creates/updates .pot template files with all msgids (empty msgstr)
  3. Extracts all translations and populates corresponding .po files with msgstr entries

  ## Examples

      # Extract and populate all .po files
      mix gettext_mapper.extract

      # Extract from specific files
      mix gettext_mapper.extract lib/my_app/models.ex

      # Dry run (show what would be extracted without modifying files)
      mix gettext_mapper.extract --dry-run

      # Use specific backend and priv directory
      mix gettext_mapper.extract --backend MyApp.Gettext --priv priv/gettext

  ## How it works

  1. Finds all `gettext_mapper(%{...})` calls with static translation maps
  2. Extracts the msgid (custom msgid option takes priority over default locale message)
  3. For each locale in the map, updates the corresponding .po file with the translation
  4. Creates new msgid/msgstr entries or updates existing ones

  ## Custom Message IDs

  The task supports the `msgid` option for stable translation keys:

      gettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, msgid: "greeting.hello")

  This creates .po entries with the custom msgid:

      # de/LC_MESSAGES/default.po
      msgid "greeting.hello"
      msgstr "Hallo"

  This allows you to use stable keys that don't change when the source text changes.

  ## Example

  From code:
  ```elixir
  def greeting do
    gettext_mapper(%{"de" => "Hello World", "en" => "Hello World", "uk" => "Hello World"})
  end
  ```

  Creates in de/LC_MESSAGES/default.po:
  ```
  msgid "Hello World"
  msgstr "Hallo Welt"
  ```

  Creates in uk/LC_MESSAGES/default.po:
  ```
  msgid "Hello World"
  msgstr "Привіт Світ"
  ```
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
        switches: [dry_run: :boolean, backend: :string, priv: :string],
        aliases: [d: :dry_run, b: :backend, p: :priv]
      )

    dry_run = Keyword.get(opts, :dry_run, false)
    backend = GettextAPI.get_backend(opts)
    priv_dir = Keyword.get(opts, :priv) || GettextAPI.priv_dir(backend)

    files_to_process =
      if Enum.empty?(paths) do
        find_elixir_files()
      else
        expand_paths(paths)
      end

    if dry_run do
      Mix.shell().info("Running in dry-run mode. No .po files will be modified.")
    end

    # Collect all translation maps from files using AST parsing
    all_translations = collect_translation_maps(files_to_process)

    if Enum.empty?(all_translations) do
      Mix.shell().info("No static translation maps found in specified files.")
    else
      # Group by msgid and populate .po files
      populate_po_files(all_translations, backend, priv_dir, dry_run)

      count = length(all_translations)
      Mix.shell().info("Processed #{count} translation maps and updated .po files.")
    end
  end

  defp find_elixir_files do
    "lib/**/*.ex"
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
  end

  defp expand_paths(paths) do
    Enum.flat_map(paths, fn path ->
      cond do
        File.regular?(path) ->
          [path]

        File.dir?(path) ->
          Path.wildcard(Path.join(path, "**/*.ex"))
          |> Enum.filter(&File.regular?/1)

        true ->
          # Path doesn't exist or is something else, skip silently
          []
      end
    end)
  end

  defp collect_translation_maps(files) do
    Enum.flat_map(files, &extract_maps_from_file/1)
  end

  defp extract_maps_from_file(file_path) do
    try do
      content = File.read!(file_path)

      # Use AST-based parsing
      calls = CodeParser.find_gettext_mapper_calls(content)

      Enum.map(calls, fn call_info ->
        %{
          translations: call_info.translations,
          domain: call_info.domain || GettextAPI.default_domain(),
          msgid: call_info.msgid,
          source: "#{file_path}:#{call_info.line}"
        }
      end)
    rescue
      error ->
        Mix.shell().error("Error reading #{file_path}: #{Exception.message(error)}")
        []
    end
  end

  defp populate_po_files(translation_maps, backend, priv_dir, dry_run) do
    # Get default locale to use as msgid source
    default_locale = GettextAPI.default_locale_for(backend)

    # Group by msgid and domain
    grouped_by_msgid_and_domain =
      Enum.reduce(translation_maps, %{}, fn entry, acc ->
        %{translations: translations, domain: domain, msgid: custom_msgid} = entry

        # Use custom msgid if provided, otherwise use default locale message
        msgid = custom_msgid || Map.get(translations, default_locale)

        case msgid do
          nil ->
            acc

          msgid ->
            key = {msgid, domain}
            existing = Map.get(acc, key, [])
            Map.put(acc, key, [{translations, entry.source} | existing])
        end
      end)

    # Group msgids by domain for .pot file generation
    msgids_by_domain =
      Enum.reduce(grouped_by_msgid_and_domain, %{}, fn {{msgid, domain}, _}, acc ->
        existing = Map.get(acc, domain, [])
        Map.put(acc, domain, [msgid | existing])
      end)

    # Create/update .pot files for each domain
    Enum.each(msgids_by_domain, fn {domain, msgids} ->
      update_pot_file(priv_dir, domain, Enum.uniq(msgids), dry_run)
    end)

    # For each msgid/domain combination, update all relevant .po files
    Enum.each(grouped_by_msgid_and_domain, fn {{msgid, domain}, translation_groups} ->
      # Merge all translations for this msgid (in case of duplicates)
      merged_translations = merge_translation_groups(translation_groups)

      # Check if this is a custom msgid (msgid differs from default locale text)
      default_locale_text = Map.get(merged_translations, default_locale)
      has_custom_msgid = default_locale_text != nil and default_locale_text != msgid

      # Update .po files for each locale
      # Skip default locale only if msgid equals the default locale text
      Enum.each(merged_translations, fn {locale, msgstr} ->
        if locale != default_locale or has_custom_msgid do
          update_po_file(priv_dir, locale, domain, msgid, msgstr, dry_run)
        end
      end)
    end)
  end

  defp update_pot_file(priv_dir, domain, msgids, dry_run) do
    default_domain = GettextAPI.default_domain()
    pot_filename = if domain == default_domain, do: "#{default_domain}.pot", else: "#{domain}.pot"
    pot_file_path = Path.join(priv_dir, pot_filename)

    if dry_run do
      Mix.shell().info("Would update #{pot_file_path} with #{length(msgids)} msgid(s)")
    else
      ensure_pot_file_exists(pot_file_path)

      Enum.each(msgids, fn msgid ->
        add_msgid_to_pot(pot_file_path, msgid)
      end)
    end
  end

  defp ensure_pot_file_exists(pot_file_path) do
    unless File.exists?(pot_file_path) do
      File.mkdir_p!(Path.dirname(pot_file_path))

      initial_content = """
      ## POT (Portable Object Template) file
      ## Extracted from gettext_mapper static translation maps.
      msgid ""
      msgstr ""
      "Content-Type: text/plain; charset=UTF-8\\n"
      """

      File.write!(pot_file_path, initial_content)
    end
  end

  defp add_msgid_to_pot(pot_file_path, msgid) do
    content = File.read!(pot_file_path)

    # Check if msgid already exists
    escaped_msgid = Regex.escape(msgid)
    msgid_pattern = ~r/msgid "#{escaped_msgid}"\s*\nmsgstr ""/s

    unless Regex.match?(msgid_pattern, content) do
      # Add new msgid with empty msgstr
      new_entry = "\nmsgid \"#{CodeParser.escape_string(msgid)}\"\nmsgstr \"\"\n"
      File.write!(pot_file_path, content <> new_entry)
    end
  end

  defp merge_translation_groups(translation_groups) do
    Enum.reduce(translation_groups, %{}, fn {translations, _source}, acc ->
      Map.merge(acc, translations)
    end)
  end

  defp update_po_file(priv_dir, locale, domain, msgid, msgstr, dry_run) do
    default_domain = GettextAPI.default_domain()
    po_filename = if domain == default_domain, do: "#{default_domain}.po", else: "#{domain}.po"
    po_file_path = Path.join([priv_dir, locale, "LC_MESSAGES", po_filename])

    if dry_run do
      Mix.shell().info("Would update #{po_file_path}: msgid \"#{msgid}\" -> msgstr \"#{msgstr}\"")
    else
      ensure_po_file_exists(po_file_path, locale)
      add_or_update_translation(po_file_path, msgid, msgstr)
    end
  end

  defp ensure_po_file_exists(po_file_path, locale) do
    unless File.exists?(po_file_path) do
      File.mkdir_p!(Path.dirname(po_file_path))

      initial_content = """
      ## "Language: #{locale}" translations
      msgid ""
      msgstr ""
      "Language: #{locale}\\n"
      "Content-Type: text/plain; charset=UTF-8\\n"
      """

      File.write!(po_file_path, initial_content)
    end
  end

  defp add_or_update_translation(po_file_path, msgid, msgstr) do
    content = File.read!(po_file_path)

    # Check if msgid already exists
    msgid_pattern = ~r/msgid "#{Regex.escape(msgid)}"\s*\nmsgstr "[^"]*"/s

    if Regex.match?(msgid_pattern, content) do
      # Update existing translation
      updated_content =
        Regex.replace(
          msgid_pattern,
          content,
          "msgid \"#{msgid}\"\nmsgstr \"#{CodeParser.escape_string(msgstr)}\""
        )

      File.write!(po_file_path, updated_content)
    else
      # Add new translation
      new_entry = "\nmsgid \"#{msgid}\"\nmsgstr \"#{CodeParser.escape_string(msgstr)}\"\n"
      File.write!(po_file_path, content <> new_entry)
    end
  end
end
