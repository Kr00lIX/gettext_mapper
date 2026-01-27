defmodule GettextMapper.Macros do
  @moduledoc """
  Macros for generating translation maps from Gettext calls and validating translation maps.

  ## Macros

  - `gettext_mapper/2` - Returns a translation map
  - `lgettext_mapper/2` - Returns the localized string for the current locale

  ## Examples

      use GettextMapper

      # Returns the full map
      gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
      #=> %{"en" => "Hello", "de" => "Hallo"}

      # Returns the localized string for current locale
      lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
      #=> "Hello" (when locale is "en")

      # With custom msgid
      lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, msgid: "greeting.hello")
      #=> "Hello" (when locale is "en")
  """
  alias GettextMapper.GettextAPI

  @doc """
  Returns a translation map, validating structure and enabling gettext extraction.

  ## Options

  - `:domain` - The gettext domain (default: configured default domain)
  - `:msgid` - Custom message ID for stable translation keys

  ## Examples

      gettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
      #=> %{"en" => "Hello", "de" => "Hallo"}

      gettext_mapper(%{"en" => "Hello"}, msgid: "greeting.hello", domain: "ui")
      #=> %{"en" => "Hello", ...}
  """
  defmacro gettext_mapper(translation_source, opts \\ []) do
    # Get domain from opts or module attribute
    domain =
      quote do
        case unquote(Keyword.get(opts, :domain)) do
          nil -> @gettext_mapper_domain
          domain -> domain
        end
      end

    case translation_source do
      # Handle gettext function calls
      {gettext_fn, _, _}
      when gettext_fn in [
             :gettext,
             :dgettext,
             :ngettext,
             :dngettext,
             :pgettext,
             :dpgettext,
             :pngettext,
             :dpngettext
           ] ->
        generate_map_from_gettext(translation_source, opts, __CALLER__, domain)

      # Handle static translation maps
      {:%{}, _, _} = map_ast ->
        sync_map_with_gettext(map_ast, opts, __CALLER__, domain)

      # Handle map variables or other expressions that should be maps
      _ ->
        quote do
          case unquote(translation_source) do
            map when is_map(map) ->
              unquote(sync_map_with_gettext(translation_source, opts, __CALLER__, domain))

            _ ->
              raise ArgumentError,
                    "gettext_mapper expects either a gettext function call or a translation map"
          end
        end
    end
  end

  @doc """
  Returns the localized string for the current locale from a translation map.

  This is a convenience macro that combines `gettext_mapper/2` with `GettextMapper.localize/1`.
  It validates the translation map, enables gettext extraction, and returns the translation
  for the current locale.

  ## Options

  - `:domain` - The gettext domain (default: configured default domain)
  - `:msgid` - Custom message ID for stable translation keys
  - `:default` - Fallback value if no translation is found (default: "")

  ## Examples

      # Returns localized string for current locale
      lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"})
      #=> "Hello" (when locale is "en")
      #=> "Hallo" (when locale is "de")

      # With custom msgid
      lgettext_mapper(%{"en" => "Hello", "de" => "Hallo"}, msgid: "greeting.hello")
      #=> "Hello" (when locale is "en")

      # With default fallback
      lgettext_mapper(%{"en" => "Hello"}, default: "No translation")
      #=> "No translation" (when locale is "fr" and "fr" not in map)

      # With domain
      lgettext_mapper(%{"en" => "Error"}, domain: "errors", msgid: "error.generic")
      #=> "Error" (when locale is "en")
  """
  defmacro lgettext_mapper(translation_source, opts \\ []) do
    default = Keyword.get(opts, :default, "")
    # Remove :default from opts as it's not used by gettext_mapper
    mapper_opts = Keyword.delete(opts, :default)

    # Get domain from opts or module attribute
    domain =
      quote do
        case unquote(Keyword.get(mapper_opts, :domain)) do
          nil -> @gettext_mapper_domain
          domain -> domain
        end
      end

    map_result =
      case translation_source do
        # Handle gettext function calls
        {gettext_fn, _, _}
        when gettext_fn in [
               :gettext,
               :dgettext,
               :ngettext,
               :dngettext,
               :pgettext,
               :dpgettext,
               :pngettext,
               :dpngettext
             ] ->
          generate_map_from_gettext(translation_source, mapper_opts, __CALLER__, domain)

        # Handle static translation maps
        {:%{}, _, _} = map_ast ->
          sync_map_with_gettext(map_ast, mapper_opts, __CALLER__, domain)

        # Handle map variables or other expressions that should be maps
        _ ->
          quote do
            case unquote(translation_source) do
              map when is_map(map) ->
                unquote(sync_map_with_gettext(translation_source, mapper_opts, __CALLER__, domain))

              _ ->
                raise ArgumentError,
                      "lgettext_mapper expects either a gettext function call or a translation map"
            end
          end
      end

    quote do
      GettextMapper.localize(unquote(map_result), unquote(default))
    end
  end

  defp generate_map_from_gettext(gettext_call_ast, _opts, caller, domain) do
    gettext_backend = backend(caller)

    known_locales = GettextAPI.known_locales()
    # default_locale = Keyword.get(opts, :default_locale, GettextAPI.default_locale())

    # Parse the gettext call to extract message and domain info
    {message_ast, call_domain} = parse_gettext_call(gettext_call_ast, domain)

    entries =
      known_locales
      |> Enum.map(fn locale ->
        quote do
          {
            unquote(locale),
            Gettext.with_locale(unquote(gettext_backend), unquote(locale), fn ->
              Gettext.dgettext(
                unquote(gettext_backend),
                unquote(call_domain),
                unquote(message_ast)
              )
            end)
          }
        end
      end)

    quote do
      Enum.into([unquote_splicing(entries)], %{})
    end
  end

  # Parse different gettext call patterns to extract message and domain
  defp parse_gettext_call({:gettext, _, [message]}, _default_domain) do
    {message, GettextAPI.default_domain()}
  end

  defp parse_gettext_call({:dgettext, _, [domain, message]}, _default_domain) do
    {message, domain}
  end

  defp parse_gettext_call({:ngettext, _, [singular, _plural, _count]}, _default_domain) do
    {singular, GettextAPI.default_domain()}
  end

  defp parse_gettext_call({:dngettext, _, [domain, singular, _plural, _count]}, _default_domain) do
    {singular, domain}
  end

  defp parse_gettext_call({:pgettext, _, [_context, message]}, _default_domain) do
    {message, GettextAPI.default_domain()}
  end

  defp parse_gettext_call({:dpgettext, _, [domain, _context, message]}, _default_domain) do
    {message, domain}
  end

  defp parse_gettext_call({:pngettext, _, [_context, singular, _plural, _count]}, _default_domain) do
    {singular, GettextAPI.default_domain()}
  end

  defp parse_gettext_call(
         {:dpngettext, _, [domain, _context, singular, _plural, _count]},
         _default_domain
       ) do
    {singular, domain}
  end

  # Fallback for unknown calls - just use the original call with default domain
  defp parse_gettext_call(call, _default_domain) do
    {call, GettextAPI.default_domain()}
  end

  defp sync_map_with_gettext(map_ast, opts, caller, domain) do
    gettext_backend = backend(caller)
    _domain = Keyword.get(opts, :domain, GettextAPI.default_domain())
    custom_msgid = Keyword.get(opts, :msgid)

    # For extraction: if this is a literal map, extract the default locale message
    extracted_calls = extract_messages_for_gettext(map_ast, gettext_backend, domain, custom_msgid)

    quote do
      map = unquote(map_ast)

      # Get known locales or fall back to map keys if none configured
      known_locales = unquote(GettextAPI.known_locales())
      locales_to_validate = if Enum.empty?(known_locales), do: Map.keys(map), else: known_locales

      # Validate the map structure
      unquote(__MODULE__).validate_translation_map!(map, locales_to_validate)

      # Execute extraction calls for gettext tools
      unquote_splicing(extracted_calls)

      # Return the original map
      map
    end
  end

  # Extract messages from literal maps for gettext extraction
  defp extract_messages_for_gettext({:%{}, _, pairs}, backend, domain, custom_msgid) do
    # Find default language message from literal map pairs
    default_message = find_default_language_message(pairs)

    # Use custom msgid if provided, otherwise use default locale message
    msgid_to_use = custom_msgid || default_message

    # Also extract all locale translations for seeding gettext files
    all_translations = extract_all_translations(pairs)

    extraction_calls = []

    # Add main gettext/dgettext call for extraction tools based on domain
    extraction_calls =
      if msgid_to_use do
        [
          quote do
            # This call is for gettext extraction tools
            domain_value = unquote(domain)
            default_domain = GettextMapper.GettextAPI.default_domain()

            _ =
              if domain_value == default_domain do
                Gettext.gettext(unquote(backend), unquote(msgid_to_use))
              else
                Gettext.dgettext(unquote(backend), domain_value, unquote(msgid_to_use))
              end
          end
          | extraction_calls
        ]
      else
        extraction_calls
      end

    # Add calls to seed translations in each locale
    extraction_calls =
      Enum.reduce(all_translations, extraction_calls, fn {locale, message}, acc ->
        if locale != GettextAPI.default_locale() and message do
          [
            quote do
              # Seed translation for locale-specific extraction
              _ =
                Gettext.with_locale(unquote(backend), unquote(locale), fn ->
                  domain_value = unquote(domain)
                  default_domain = GettextMapper.GettextAPI.default_domain()

                  if domain_value == default_domain do
                    Gettext.gettext(unquote(backend), unquote(msgid_to_use || message))
                  else
                    Gettext.dgettext(
                      unquote(backend),
                      domain_value,
                      unquote(msgid_to_use || message)
                    )
                  end
                end)
            end
            | acc
          ]
        else
          acc
        end
      end)

    extraction_calls
  end

  defp extract_messages_for_gettext(_, _, _, _), do: []

  # Find default language message from map literal pairs
  defp find_default_language_message(pairs) do
    default_locale = GettextAPI.default_locale()

    Enum.find_value(pairs, fn
      {key, value} when is_binary(key) or (is_tuple(key) and elem(key, 0) == :<<>>) ->
        key_str = extract_string_literal(key)
        if key_str == default_locale, do: extract_string_literal(value), else: nil

      _ ->
        nil
    end)
  end

  # Extract all translations from map literal pairs
  defp extract_all_translations(pairs) do
    Enum.reduce(pairs, %{}, fn
      {key, value}, acc when is_binary(key) or (is_tuple(key) and elem(key, 0) == :<<>>) ->
        key_str = extract_string_literal(key)
        value_str = extract_string_literal(value)

        if key_str && value_str do
          Map.put(acc, key_str, value_str)
        else
          acc
        end

      _, acc ->
        acc
    end)
  end

  # Extract string from AST literal
  defp extract_string_literal({:<<>>, _, [value]}) when is_binary(value), do: value
  defp extract_string_literal(value) when is_binary(value), do: value
  defp extract_string_literal(_), do: nil

  defp backend(%Macro.Env{} = env) do
    Module.get_attribute(env.module, :__gettext_backend__) || GettextAPI.gettext_module()
  end

  @doc """
  Validates that a translation map has the correct structure.

  Ensures:
  - All supported locales are present as keys
  - All values are strings
  - No extra locales are present
  """
  def validate_translation_map!(map, supported_locales)
      when is_map(map) and is_list(supported_locales) do
    map_locales = MapSet.new(Map.keys(map))
    supported_set = MapSet.new(supported_locales)

    # Check for missing locales
    missing_locales = MapSet.difference(supported_set, map_locales)

    unless MapSet.size(missing_locales) == 0 do
      raise ArgumentError,
            "Translation map is missing required locales: #{inspect(MapSet.to_list(missing_locales))}"
    end

    # Check for extra locales
    extra_locales = MapSet.difference(map_locales, supported_set)

    unless MapSet.size(extra_locales) == 0 do
      raise ArgumentError,
            "Translation map contains unsupported locales: #{inspect(MapSet.to_list(extra_locales))}"
    end

    # Check that all values are strings
    non_string_values =
      map
      |> Enum.reject(fn {_locale, value} -> is_binary(value) end)
      |> Enum.map(fn {locale, _value} -> locale end)

    unless Enum.empty?(non_string_values) do
      raise ArgumentError,
            "Translation map contains non-string values for locales: #{inspect(non_string_values)}"
    end

    :ok
  end

  def validate_translation_map!(value, _supported_locales) do
    raise ArgumentError, "Expected a map for translation validation, got: #{inspect(value)}"
  end
end
