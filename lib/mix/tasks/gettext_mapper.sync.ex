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
  formatting conventions. This means:

  - Consistent spacing around `=>` operators
  - Proper indentation for multiline maps
  - Standard quote style
  - Proper alignment and line breaks

  ## Example transformation

  Before:
  ```elixir
  def hello do
    gettext_mapper(%{"de" => "Hello!", "en" => "Hello!", "uk" => "Hello!"})
  end
  ```

  After (if .po files were updated with "!" suffix):
  ```elixir
  def hello do
    gettext_mapper(%{"de" => "Hello!", "en" => "Hello!", "uk" => "Hello!"})
  end
  ```
  """

  use Mix.Task

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
    backend = get_backend(opts)
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
      default_domain = GettextMapper.GettextAPI.default_domain()
      translation_map = generate_translation_map(message, backend, default_domain)

      Mix.shell().info("Original message: \"#{message}\"")
      Mix.shell().info("Updated translation map:")
      Mix.shell().info(format_elixir_map(translation_map))
    rescue
      error ->
        Mix.shell().error("Error: #{Exception.message(error)}")
    end
  end

  defp get_backend(opts) do
    case Keyword.get(opts, :backend) do
      nil ->
        try do
          GettextMapper.GettextAPI.gettext_module()
        rescue
          _error ->
            # Try to load test environment
            if File.exists?("test/test_helper.exs") do
              Code.require_file("test/test_helper.exs")
              GettextMapper.GettextAPI.gettext_module()
            else
              reraise "No gettext backend configured. Use --backend YourApp.Gettext or configure :gettext_mapper, :gettext",
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
    # Split content into lines to check for comments
    lines = String.split(content, "\n")

    # Regex to find gettext_mapper calls with static maps, optionally with domain and/or msgid
    # Captures: 1=map_content, 2=first_opt_key, 3=first_opt_value, 4=second_opt_key, 5=second_opt_value
    regex =
      ~r/gettext_mapper\(\s*%\{([^}]+)\}\s*(?:,\s*(domain|msgid):\s*"([^"]+)")?(?:,\s*(domain|msgid):\s*"([^"]+)")?\s*\)/s

    Regex.replace(regex, content, fn full_match,
                                     map_content,
                                     opt1_key,
                                     opt1_val,
                                     opt2_key,
                                     opt2_val ->
      # Check if this match is inside a comment
      if in_comment?(full_match, content, lines) do
        # Return the match unchanged if it's in a comment
        full_match
      else
        # Parse options from captured groups
        opts = parse_options(opt1_key, opt1_val, opt2_key, opt2_val)
        domain = Map.get(opts, "domain", GettextMapper.GettextAPI.default_domain())
        custom_msgid = Map.get(opts, "msgid")

        process_translation_map(map_content, domain, custom_msgid, backend, full_match)
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

  defp in_comment?(match_text, full_content, _lines) do
    # Find the position of the match in the content
    case :binary.match(full_content, match_text) do
      {pos, _len} ->
        # Check if this match is in a line comment, @moduledoc, or @doc section
        line_comment?(full_content, pos) or doc_section?(full_content, pos)

      :nomatch ->
        false
    end
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

  defp process_translation_map(map_content, domain, custom_msgid, backend, full_match) do
    case parse_translation_map(map_content) do
      {:ok, translations} ->
        # Use custom msgid if provided, otherwise try default locale message
        default_locale = get_default_locale(backend)
        default_message = Map.get(translations, default_locale)

        # Determine which msgid to use for lookup
        lookup_msgid = custom_msgid || default_message || Map.get(translations, "en")

        if lookup_msgid do
          updated_translations = generate_translation_map(lookup_msgid, backend, domain)

          format_translation_map_call_with_elixir_formatter(
            updated_translations,
            domain,
            custom_msgid
          )
        else
          # Return original if we can't find a suitable message
          full_match
        end

      :error ->
        # Return original if parsing fails
        full_match
    end
  end

  defp parse_translation_map(map_string) do
    try do
      # Clean up the map string
      cleaned =
        map_string
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      # Parse key-value pairs with various quote styles
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

  defp get_default_locale(backend) do
    try do
      backend.__gettext__(:default_locale)
    rescue
      _ -> "en"
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
    # Get the priv directory for the backend
    priv_dir =
      try do
        backend.__gettext__(:priv)
      rescue
        _ -> "priv/gettext"
      end

    default_domain = GettextMapper.GettextAPI.default_domain()
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
    # Get the priv directory for the backend
    priv_dir =
      try do
        backend.__gettext__(:priv)
      rescue
        _ -> "priv/gettext"
      end

    default_domain = GettextMapper.GettextAPI.default_domain()
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
      [GettextMapper.GettextAPI.default_locale()]
    end
  end

  # Format using Elixir's built-in formatter for consistent, idiomatic formatting
  defp format_translation_map_call_with_elixir_formatter(translations, domain, custom_msgid) do
    default_domain = GettextMapper.GettextAPI.default_domain()

    # Create unformatted string with translations
    entries =
      Enum.map(translations, fn {locale, translation} ->
        ~s("#{locale}" => "#{escape_string(translation)}")
      end)

    # Build options list
    opts = []
    opts = if domain != default_domain, do: ["domain: \"#{domain}\"" | opts], else: opts
    opts = if custom_msgid, do: ["msgid: \"#{custom_msgid}\"" | opts], else: opts
    opts = Enum.reverse(opts)

    # Build the basic call
    unformatted =
      if Enum.empty?(opts) do
        "gettext_mapper(%{#{Enum.join(entries, ", ")}})"
      else
        "gettext_mapper(%{#{Enum.join(entries, ", ")}}, #{Enum.join(opts, ", ")})"
      end

    # Use Elixir's formatter for consistent formatting
    try do
      Code.format_string!(unformatted) |> to_string()
    rescue
      _ ->
        # Fallback to unformatted if formatting fails
        unformatted
    end
  end

  defp format_elixir_map(map) do
    entries =
      Enum.map(map, fn {locale, translation} ->
        ~s("#{locale}" => "#{escape_string(translation)}")
      end)

    "%{#{Enum.join(entries, ", ")}}"
  end

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
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
