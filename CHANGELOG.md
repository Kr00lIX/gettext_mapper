# Changelog

All notable changes to this project will be documented in this file.

## 0.1.0 - 2025-06-25

### Added
- Ecto.Type `GettextMapper.Ecto.Type.Translated` for storing locale-to-string maps
  in a JSON/map column, with `type/0`, `cast/1`, `load/1`, and `dump/1` callbacks.
- Helper functions `GettextMapper.localize/2` and `GettextMapper.translate/2`
  for fetching localized strings with fallback support.

### Changed
- Moved `localize/2` and `translate/2` from the `GettextMapper.Ecto.Type.Translated`
  module to the root `GettextMapper` module.
- Introduced `:default_translation` application config (defaults to "NO TRANSLATION")
  to customize the fallback translation message.

### Documentation
- Updated `README.md` with badges, detailed installation, configuration,
  usage examples, and configuration instructions for the new default
  translation setting.

### Testing
- Added comprehensive unit and doctests covering Ecto.Type callbacks and
  helper functions, with a `TestGettext` stub backend for locale simulation.