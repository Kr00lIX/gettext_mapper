defmodule GettextMapper.CodeParser do
  @moduledoc """
  Provides AST-based parsing utilities for finding and analyzing gettext_mapper calls in Elixir code.

  This module replaces regex-based parsing with proper Elixir AST analysis,
  providing more robust and reliable code parsing.
  """

  @type call_info :: %{
          line: pos_integer(),
          translations: %{String.t() => String.t()},
          domain: String.t() | nil,
          msgid: String.t() | nil,
          raw_match: String.t()
        }

  @doc """
  Finds all gettext_mapper calls in the given file content using AST parsing.

  Returns a list of maps containing:
  - `:line` - the line number of the call
  - `:translations` - the parsed translation map
  - `:domain` - the domain option if specified
  - `:msgid` - the custom msgid option if specified
  - `:raw_match` - the raw source code of the call (for replacement)

  ## Examples

      iex> content = ~s|gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})|
      iex> [call] = GettextMapper.CodeParser.find_gettext_mapper_calls(content)
      iex> call.translations
      %{"de" => "Hallo", "en" => "Hello"}
      iex> call.line
      1

      # With domain option
      iex> content = ~s|gettext_mapper(%{"en" => "Hello"}, domain: "admin")|
      iex> [call] = GettextMapper.CodeParser.find_gettext_mapper_calls(content)
      iex> call.domain
      "admin"

      # With custom msgid
      iex> content = ~s|gettext_mapper(%{"en" => "Hello"}, msgid: "greeting.hello")|
      iex> [call] = GettextMapper.CodeParser.find_gettext_mapper_calls(content)
      iex> call.msgid
      "greeting.hello"
  """
  @spec find_gettext_mapper_calls(String.t()) :: [call_info()]
  def find_gettext_mapper_calls(content) do
    # First extract module-level domain
    module_domain = extract_module_domain(content)

    case Code.string_to_quoted(content, columns: true, token_metadata: true) do
      {:ok, ast} ->
        find_calls_in_ast(ast, content, module_domain)

      {:error, _} ->
        # Fallback to empty list on parse error
        []
    end
  end

  @doc """
  Extracts module-level domain from `use GettextMapper, domain: "..."` declarations.

  ## Examples

      iex> content = ~s|use GettextMapper, domain: "admin"|
      iex> GettextMapper.CodeParser.extract_module_domain(content)
      "admin"

      iex> GettextMapper.CodeParser.extract_module_domain("use GettextMapper")
      nil
  """
  @spec extract_module_domain(String.t()) :: String.t() | nil
  def extract_module_domain(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} ->
        find_module_domain_in_ast(ast)

      {:error, _} ->
        nil
    end
  end

  @doc """
  Parses a translation map from its string representation.

  Handles both inline and multiline maps with proper escaping.

  ## Examples

      iex> GettextMapper.CodeParser.parse_translation_map(~s|"en" => "Hello", "de" => "Hallo"|)
      {:ok, %{"en" => "Hello", "de" => "Hallo"}}

      iex> GettextMapper.CodeParser.parse_translation_map("invalid")
      :error
  """
  @spec parse_translation_map(String.t()) :: {:ok, %{String.t() => String.t()}} | :error
  def parse_translation_map(map_string) do
    # Try to parse as a complete map expression
    map_code = "%{#{map_string}}"

    case Code.string_to_quoted(map_code) do
      {:ok, {:%{}, _, pairs}} ->
        translations =
          Enum.reduce(pairs, %{}, fn
            {key, value}, acc when is_binary(key) and is_binary(value) ->
              Map.put(acc, key, value)

            _, acc ->
              acc
          end)

        if map_size(translations) > 0 do
          {:ok, translations}
        else
          :error
        end

      _ ->
        :error
    end
  end

  @doc """
  Escapes a string for safe inclusion in Elixir source code or .po files.

  Handles backslashes and double quotes that need escaping.

  ## Examples

      iex> GettextMapper.CodeParser.escape_string("Hello World")
      "Hello World"

  Double quotes are escaped with backslashes:

      escape_string("Hello \"World\"")
      #=> "Hello \\\"World\\\""

  Backslashes are also escaped:

      escape_string("path\\to\\file")
      #=> "path\\\\to\\\\file"
  """
  @spec escape_string(String.t()) :: String.t()
  def escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  @doc """
  Generates a formatted gettext_mapper or lgettext_mapper call string from translations and options.

  Uses Elixir's Code.format_string!/2 for consistent formatting.

  ## Parameters

  - `translations` - Map of locale => translation string
  - `domain` - Optional domain (nil uses default, non-default domains are included)
  - `custom_msgid` - Optional custom message ID for stable translation keys
  - `macro_name` - The macro name to use (`:gettext_mapper` or `:lgettext_mapper`), defaults to `:gettext_mapper`
  - `locale_order` - Optional list of locales specifying the output order. If nil, sorts alphabetically.

  ## Examples

      iex> GettextMapper.CodeParser.format_gettext_mapper_call(%{"en" => "Hello"}, nil, nil)
      "gettext_mapper(%{\\"en\\" => \\"Hello\\"})"

      iex> GettextMapper.CodeParser.format_gettext_mapper_call(%{"en" => "Hello", "de" => "Hallo"}, nil, nil)
      "gettext_mapper(%{\\"de\\" => \\"Hallo\\", \\"en\\" => \\"Hello\\"})"

      # With custom domain (non-default)
      iex> GettextMapper.CodeParser.format_gettext_mapper_call(%{"en" => "Hello"}, "admin", nil)
      "gettext_mapper(%{\\"en\\" => \\"Hello\\"}, domain: \\"admin\\")"

      # With custom msgid
      iex> GettextMapper.CodeParser.format_gettext_mapper_call(%{"en" => "Hello"}, nil, "greeting.hello")
      "gettext_mapper(%{\\"en\\" => \\"Hello\\"}, msgid: \\"greeting.hello\\")"

      # With lgettext_mapper macro
      iex> GettextMapper.CodeParser.format_gettext_mapper_call(%{"en" => "Hello"}, nil, nil, :lgettext_mapper)
      "lgettext_mapper(%{\\"en\\" => \\"Hello\\"})"

      # With preserved locale order
      iex> GettextMapper.CodeParser.format_gettext_mapper_call(%{"en" => "Hello", "de" => "Hallo"}, nil, nil, :gettext_mapper, ["en", "de"])
      "gettext_mapper(%{\\"en\\" => \\"Hello\\", \\"de\\" => \\"Hallo\\"})"
  """
  @spec format_gettext_mapper_call(map(), String.t() | nil, String.t() | nil, atom(), list() | nil) ::
          String.t()
  def format_gettext_mapper_call(
        translations,
        domain,
        custom_msgid,
        macro_name \\ :gettext_mapper,
        locale_order \\ nil
      ) do
    default_domain = GettextMapper.GettextAPI.default_domain()

    # Create entries for the map, preserving order if provided
    ordered_locales =
      if locale_order do
        # Use provided order, then append any new locales alphabetically
        new_locales = Map.keys(translations) -- locale_order
        locale_order ++ Enum.sort(new_locales)
      else
        # Default: sort alphabetically
        translations |> Map.keys() |> Enum.sort()
      end

    entries =
      ordered_locales
      |> Enum.filter(&Map.has_key?(translations, &1))
      |> Enum.map(fn locale ->
        translation = Map.get(translations, locale)
        ~s("#{locale}" => "#{escape_string(translation)}")
      end)

    # Build options list
    opts = []
    opts = if domain && domain != default_domain, do: ["domain: \"#{domain}\"" | opts], else: opts
    opts = if custom_msgid, do: ["msgid: \"#{custom_msgid}\"" | opts], else: opts
    opts = Enum.reverse(opts)

    # Build the call
    macro_str = Atom.to_string(macro_name)

    unformatted =
      if Enum.empty?(opts) do
        "#{macro_str}(%{#{Enum.join(entries, ", ")}})"
      else
        "#{macro_str}(%{#{Enum.join(entries, ", ")}}, #{Enum.join(opts, ", ")})"
      end

    # Format using Elixir's formatter
    try do
      Code.format_string!(unformatted) |> to_string()
    rescue
      _ -> unformatted
    end
  end

  @doc """
  Extracts the raw source code for a gettext_mapper call at the given line.

  This is used to get the exact string to replace in the original file when
  syncing translations. It handles multiline calls and properly balances
  parentheses.

  ## Parameters

  - `content` - The full file content as a string
  - `line_number` - The 1-based line number where the call starts

  ## Examples

      iex> content = "def foo do\\n  gettext_mapper(%{\\"en\\" => \\"Hello\\"})\\nend"
      iex> GettextMapper.CodeParser.extract_call_source(content, 2)
      "  gettext_mapper(%{\\"en\\" => \\"Hello\\"})"

      iex> GettextMapper.CodeParser.extract_call_source("no calls here", 1)
      nil
  """
  @spec extract_call_source(String.t(), pos_integer()) :: String.t() | nil
  def extract_call_source(content, line_number) do
    lines = String.split(content, "\n")

    # Start from the given line and collect until we have a complete expression
    start_index = line_number - 1

    if start_index >= 0 and start_index < length(lines) do
      extract_complete_call(lines, start_index)
    else
      nil
    end
  end

  # Private functions

  defp find_calls_in_ast(ast, content, module_domain) do
    {_, calls} =
      Macro.prewalk(ast, [], fn
        # Match gettext_mapper with map and options
        {:gettext_mapper, meta, [{:%{}, _, pairs} | opts_ast]} = node, acc ->
          line = Keyword.get(meta, :line, 0)

          case parse_ast_pairs(pairs) do
            {:ok, translations, locale_order} ->
              opts = parse_ast_options(opts_ast)
              # Track call-level domain separately from effective domain
              call_domain = Map.get(opts, :domain)
              effective_domain = call_domain || module_domain
              msgid = Map.get(opts, :msgid)
              raw_match = extract_call_source(content, line)

              call_info = %{
                line: line,
                translations: translations,
                locale_order: locale_order,
                domain: effective_domain,
                call_domain: call_domain,
                msgid: msgid,
                raw_match: raw_match,
                macro: :gettext_mapper
              }

              {node, [call_info | acc]}

            :error ->
              {node, acc}
          end

        # Match lgettext_mapper as well
        {:lgettext_mapper, meta, [{:%{}, _, pairs} | opts_ast]} = node, acc ->
          line = Keyword.get(meta, :line, 0)

          case parse_ast_pairs(pairs) do
            {:ok, translations, locale_order} ->
              opts = parse_ast_options(opts_ast)
              # Track call-level domain separately from effective domain
              call_domain = Map.get(opts, :domain)
              effective_domain = call_domain || module_domain
              msgid = Map.get(opts, :msgid)
              raw_match = extract_call_source(content, line)

              call_info = %{
                line: line,
                translations: translations,
                locale_order: locale_order,
                domain: effective_domain,
                call_domain: call_domain,
                msgid: msgid,
                raw_match: raw_match,
                macro: :lgettext_mapper
              }

              {node, [call_info | acc]}

            :error ->
              {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(calls)
  end

  defp find_module_domain_in_ast(ast) do
    {_, domain} =
      Macro.prewalk(ast, nil, fn
        # Match: use GettextMapper, domain: "..." or use GettextMapper, [domain: "..."]
        {:use, _, [{:__aliases__, _, [:GettextMapper]} | opts]} = node, acc ->
          case extract_domain_from_use_opts(opts) do
            nil -> {node, acc}
            found_domain -> {node, found_domain}
          end

        node, acc ->
          {node, acc}
      end)

    domain
  end

  defp extract_domain_from_use_opts([opts]) when is_list(opts) do
    case Keyword.get(opts, :domain) do
      domain when is_binary(domain) -> domain
      _ -> nil
    end
  end

  defp extract_domain_from_use_opts(_), do: nil

  defp parse_ast_pairs(pairs) do
    # Extract translations and preserve original key order
    {translations, locale_order} =
      Enum.reduce(pairs, {%{}, []}, fn
        {key, value}, {map, order} when is_binary(key) and is_binary(value) ->
          {Map.put(map, key, value), order ++ [key]}

        _, acc ->
          acc
      end)

    if map_size(translations) > 0 do
      {:ok, translations, locale_order}
    else
      :error
    end
  end

  defp parse_ast_options([opts]) when is_list(opts) do
    Enum.reduce(opts, %{}, fn
      {:domain, value}, acc when is_binary(value) ->
        Map.put(acc, :domain, value)

      {:msgid, value}, acc when is_binary(value) ->
        Map.put(acc, :msgid, value)

      {:locale, value}, acc when is_binary(value) ->
        Map.put(acc, :locale, value)

      {:default, value}, acc when is_binary(value) ->
        Map.put(acc, :default, value)

      _, acc ->
        acc
    end)
  end

  defp parse_ast_options(_), do: %{}

  defp extract_complete_call(lines, start_index) do
    # Collect lines until we have balanced parentheses
    collect_until_balanced(lines, start_index, "", 0, false)
  end

  defp collect_until_balanced(lines, index, acc, paren_count, started) do
    if index >= length(lines) do
      # Reached end of file without finding complete expression
      if started, do: extract_gettext_mapper_call_from_text(acc), else: nil
    else
      line = Enum.at(lines, index)

      # Check if this line contains gettext_mapper
      has_start =
        String.contains?(line, "gettext_mapper(") or String.contains?(line, "lgettext_mapper(")

      if not started and not has_start do
        # Haven't found the start yet, skip
        collect_until_balanced(lines, index + 1, acc, paren_count, false)
      else
        new_acc = if acc == "", do: line, else: acc <> "\n" <> line

        # Count parentheses (simplified - doesn't handle strings perfectly but works for most cases)
        {open, close} = count_parens(line)
        new_count = paren_count + open - close
        new_started = started or has_start

        if new_started and new_count <= 0 do
          # Found complete expression, extract just the call (preserving leading whitespace)
          extract_gettext_mapper_call_from_text(new_acc)
        else
          collect_until_balanced(lines, index + 1, new_acc, new_count, new_started)
        end
      end
    end
  end

  defp count_parens(line) do
    # Simple paren counting - good enough for most cases
    # A more robust solution would properly handle strings and comments
    open = line |> String.graphemes() |> Enum.count(&(&1 == "("))
    close = line |> String.graphemes() |> Enum.count(&(&1 == ")"))
    {open, close}
  end

  defp extract_gettext_mapper_call_from_text(text) do
    # Find the gettext_mapper or lgettext_mapper call in the text
    # Check lgettext_mapper first since "lgettext_mapper" contains "gettext_mapper"
    cond do
      String.contains?(text, "lgettext_mapper(") ->
        extract_call(text, "lgettext_mapper(")

      String.contains?(text, "gettext_mapper(") ->
        extract_call(text, "gettext_mapper(")

      true ->
        nil
    end
  end

  defp extract_call(text, prefix) do
    case String.split(text, prefix, parts: 2) do
      [before, rest] ->
        # Find matching closing paren
        call_body = find_matching_close(rest, 1, "")

        if call_body do
          # Preserve leading whitespace from the line containing the call
          leading_ws = get_leading_whitespace_from_last_line(before)
          leading_ws <> prefix <> call_body
        else
          nil
        end

      _ ->
        nil
    end
  end

  defp get_leading_whitespace_from_last_line(text) do
    # Get the whitespace from the last line (or the only line) before the call
    lines = String.split(text, "\n")
    last_line = List.last(lines) || ""

    case Regex.run(~r/^(\s*)$/, last_line) do
      [_, ws] -> ws
      _ -> ""
    end
  end

  defp find_matching_close("", _count, _acc), do: nil

  defp find_matching_close(")" <> _rest, 1, acc), do: acc <> ")"

  defp find_matching_close(")" <> rest, count, acc) do
    find_matching_close(rest, count - 1, acc <> ")")
  end

  defp find_matching_close("(" <> rest, count, acc) do
    find_matching_close(rest, count + 1, acc <> "(")
  end

  defp find_matching_close(<<char::utf8, rest::binary>>, count, acc) do
    find_matching_close(rest, count, acc <> <<char::utf8>>)
  end
end
