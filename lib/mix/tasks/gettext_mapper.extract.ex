defmodule Mix.Tasks.GettextMapper.Extract do
  @shortdoc "Extract translations from static gettext_mapper maps to populate .po files"

  @moduledoc """
  Extracts both msgids and translations from static gettext_mapper maps and populates .po files.

  This task scans your codebase for `gettext_mapper(%{...})` calls with static maps and:
  1. Extracts the msgid (custom msgid if specified, otherwise default locale message)
  2. Extracts all translations and populates corresponding .po files with msgstr entries

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
    backend = get_backend(opts)
    priv_dir = Keyword.get(opts, :priv, "priv/gettext")

    files_to_process =
      if Enum.empty?(paths) do
        find_elixir_files()
      else
        paths
      end

    if dry_run do
      Mix.shell().info("Running in dry-run mode. No .po files will be modified.")
    end

    # Collect all translation maps from files
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

  defp get_backend(opts) do
    case Keyword.get(opts, :backend) do
      nil ->
        try do
          GettextMapper.GettextAPI.gettext_module()
        rescue
          _error ->
            if File.exists?("test/test_helper.exs") do
              Code.require_file("test/test_helper.exs")
              GettextMapper.GettextAPI.gettext_module()
            else
              reraise "No gettext backend configured. Use --backend YourApp.Gettext",
                      __STACKTRACE__
            end
        end

      backend_string ->
        String.to_existing_atom(backend_string)
    end
  end

  defp find_elixir_files do
    "lib/**/*.ex"
    |> Path.wildcard()
    |> Enum.filter(&File.exists?/1)
  end

  defp collect_translation_maps(files) do
    Enum.flat_map(files, &extract_maps_from_file/1)
  end

  defp extract_maps_from_file(file_path) do
    try do
      content = File.read!(file_path)
      extract_maps_from_content(content, file_path)
    rescue
      error ->
        Mix.shell().error("Error reading #{file_path}: #{Exception.message(error)}")
        []
    end
  end

  defp extract_maps_from_content(content, file_path) do
    # First extract module-level domain if present
    module_domain = extract_module_domain(content)

    # Regex to find gettext_mapper calls with static maps, optionally with domain and/or msgid
    # Captures: 1=map_content, 2=first_opt_key, 3=first_opt_value, 4=second_opt_key, 5=second_opt_value
    regex =
      ~r/gettext_mapper\(\s*%\{([^}]+)\}\s*(?:,\s*(domain|msgid):\s*"([^"]+)")?(?:,\s*(domain|msgid):\s*"([^"]+)")?\s*\)/s

    Regex.scan(regex, content, capture: :all)
    |> Enum.with_index()
    |> Enum.flat_map(fn {captures, index} ->
      full_match = Enum.at(captures, 0, "")
      map_content = Enum.at(captures, 1, "")
      opt1_key = Enum.at(captures, 2, "")
      opt1_val = Enum.at(captures, 3, "")
      opt2_key = Enum.at(captures, 4, "")
      opt2_val = Enum.at(captures, 5, "")

      # Check if this match is in a comment
      if comment_text?(content, full_match) do
        # Skip matches that are in comments
        []
      else
        # Parse options from captured groups
        opts = parse_options(opt1_key, opt1_val, opt2_key, opt2_val)

        # Determine domain priority: call-level > module-level > default
        domain =
          cond do
            Map.has_key?(opts, "domain") -> Map.get(opts, "domain")
            module_domain != nil -> module_domain
            true -> GettextMapper.GettextAPI.default_domain()
          end

        custom_msgid = Map.get(opts, "msgid")

        case parse_translation_map(map_content) do
          {:ok, translations} ->
            [{translations, domain, custom_msgid, "#{file_path}:#{index + 1}"}]

          :error ->
            Mix.shell().warn(
              "Could not parse translation map in #{file_path} at position #{index + 1}"
            )

            []
        end
      end
    end)
  end

  defp parse_options(key1, val1, key2, val2) do
    opts = %{}

    opts =
      if key1 != "" and val1 != "" do
        Map.put(opts, key1, val1)
      else
        opts
      end

    if key2 != "" and val2 != "" do
      Map.put(opts, key2, val2)
    else
      opts
    end
  end

  defp comment_text?(content, match_text) do
    # Find the position of this match in the content
    case :binary.match(content, match_text) do
      {pos, _len} ->
        comment_by_position?(content, pos)

      :nomatch ->
        false
    end
  end

  defp comment_by_position?(content, pos) do
    # Check if this position is in a line comment, @moduledoc, or @doc section
    line_comment?(content, pos) or doc_section?(content, pos)
  end

  defp line_comment?(content, pos) do
    # Check if there's a # character before this position in the same line
    content_before_match = String.slice(content, 0, pos)

    # Find the last newline before the match
    last_newline_pos =
      content_before_match
      |> String.reverse()
      |> :binary.match("\n")
      |> case do
        {reverse_pos, _} -> pos - reverse_pos - 1
        :nomatch -> 0
      end

    line_before_match =
      String.slice(content_before_match, last_newline_pos, pos - last_newline_pos)

    # Check if there's a # in the line before the match
    String.contains?(line_before_match, "#")
  end

  defp doc_section?(content, pos) do
    # Check if the match is inside @moduledoc """ or @doc """ blocks
    content_before_match = String.slice(content, 0, pos)

    # Find all doc block starts (either @doc """ or @moduledoc """)
    doc_starts =
      (Regex.scan(~r/@doc\s+"""/, content_before_match, return: :index) ++
         Regex.scan(~r/@moduledoc\s+"""/, content_before_match, return: :index))
      |> Enum.map(fn [{start, _}] -> start end)
      |> Enum.sort()

    # Find all standalone """ that are not part of @doc or @moduledoc
    all_triple_quotes =
      Regex.scan(~r/"""/, content_before_match, return: :index)
      |> Enum.map(fn [{start, _}] -> start end)
      |> Enum.sort()

    # Filter out the """ that are part of @doc/@moduledoc declarations
    doc_ends =
      Enum.reject(all_triple_quotes, fn quote_pos ->
        # Check if this """ is preceded by @doc or @moduledoc on the same or previous lines
        Enum.any?(doc_starts, fn doc_start ->
          # Rough heuristic for same declaration
          abs(quote_pos - doc_start) < 50
        end)
      end)

    # Count how many doc blocks are currently open
    open_blocks = length(doc_starts) - length(doc_ends)

    # If we have more opening doc blocks than closing """, we're inside a doc block
    open_blocks > 0
  end

  defp parse_translation_map(map_string) do
    try do
      # Clean up the map string
      cleaned =
        map_string
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      # Parse key-value pairs
      pairs = Regex.scan(~r/"([^"]+)"\s*=>\s*"([^"]*)"/, cleaned)

      translations =
        Enum.into(pairs, %{}, fn [_, key, value] ->
          {key, value}
        end)

      if map_size(translations) > 0 do
        {:ok, translations}
      else
        :error
      end
    rescue
      _ -> :error
    end
  end

  defp populate_po_files(translation_maps, backend, priv_dir, dry_run) do
    # Get default locale to use as msgid source
    default_locale = get_default_locale(backend)

    # Group by msgid and domain
    grouped_by_msgid_and_domain =
      Enum.reduce(translation_maps, %{}, fn {translations, domain, custom_msgid, source}, acc ->
        # Use custom msgid if provided, otherwise use default locale message
        msgid = custom_msgid || Map.get(translations, default_locale)

        case msgid do
          nil ->
            acc

          msgid ->
            key = {msgid, domain}
            existing = Map.get(acc, key, [])
            Map.put(acc, key, [{translations, source} | existing])
        end
      end)

    # For each msgid/domain combination, update all relevant .po files
    Enum.each(grouped_by_msgid_and_domain, fn {{msgid, domain}, translation_groups} ->
      # Merge all translations for this msgid (in case of duplicates)
      merged_translations = merge_translation_groups(translation_groups)

      # Update .po files for each locale
      Enum.each(merged_translations, fn {locale, msgstr} ->
        if locale != default_locale do
          update_po_file(priv_dir, locale, domain, msgid, msgstr, dry_run)
        end
      end)
    end)
  end

  defp merge_translation_groups(translation_groups) do
    Enum.reduce(translation_groups, %{}, fn {translations, _source}, acc ->
      Map.merge(acc, translations)
    end)
  end

  defp update_po_file(priv_dir, locale, domain, msgid, msgstr, dry_run) do
    default_domain = GettextMapper.GettextAPI.default_domain()
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
      # #{locale} translations
      msgid ""
      msgstr ""
      "Language: #{locale}\\n"

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
          "msgid \"#{msgid}\"\nmsgstr \"#{escape_string(msgstr)}\""
        )

      File.write!(po_file_path, updated_content)
    else
      # Add new translation
      new_entry = "\nmsgid \"#{msgid}\"\nmsgstr \"#{escape_string(msgstr)}\"\n"
      File.write!(po_file_path, content <> new_entry)
    end
  end

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp extract_module_domain(content) do
    # Look for `use GettextMapper, domain: "domain_name"`
    case Regex.run(~r/use\s+GettextMapper\s*,\s*domain:\s*"([^"]+)"/, content) do
      [_, domain] -> domain
      _ -> nil
    end
  end

  defp get_default_locale(backend) do
    try do
      backend.__gettext__(:default_locale)
    rescue
      _ -> "en"
    end
  end
end
