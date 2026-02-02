# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2025-02-02

### Added
- Preserve original locale order when syncing translations (new locales appended alphabetically)
- Improved documentation with doctests for all public API methods

### Fixed
- Preserve original indentation when syncing multiline `gettext_mapper` calls
- Preserve module-level domain configuration (no longer adds redundant `domain:` option)
- Handle empty translations from .po files by falling back to original values
- Preserve `lgettext_mapper` macro name during sync (was incorrectly changed to `gettext_mapper`)
- Fix mix tasks to properly handle directory paths

### Changed
- Refactored to use AST-based parsing instead of regex patterns
- Improved test coverage to 90.7%

## [0.1.2] - 2025-01-31

### Added
- `:locale` option for `lgettext_mapper` macro to specify a specific locale

### Fixed
- Updated documentation with locale parameter examples

## [0.1.1] - 2025-01-30

### Added
- `lgettext_mapper` macro to return localized string instead of full map
- Custom `msgid` parameter support for stable translation keys
- Support for Gettext >= 0.26.0 and < 2.0.0

### Fixed
- Default locale extraction improvements

## [0.1.0] - 2025-01-29

### Added
- Initial release
- `gettext_mapper` macro for static translation maps
- `GettextMapper.Ecto.Type.Translated` Ecto type for database storage
- `mix gettext_mapper.sync` task to sync translation maps with .po files
- `mix gettext_mapper.extract` task to extract translations to .po files
- Domain support for organizing translations
- Configurable supported locales
- Backend configuration options

[0.1.3]: https://github.com/kr00lix/gettext_mapper/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/kr00lix/gettext_mapper/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/kr00lix/gettext_mapper/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/kr00lix/gettext_mapper/releases/tag/v0.1.0
