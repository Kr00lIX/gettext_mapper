# defmodule GettextMapper.Translations do
#   # Helper function to get supported locales
#   # You can customize this based on how you want to retrieve your app's locales
#   defmacrop get_supported_locales do
#     # Option 1: Hardcoded list
#     quote do
#       ["en", "de", "uk"]
#     end

#     # Option 2: From application config
#     # Application.get_env(:your_app, :supported_locales, ["en"])

#     # Option 3: From Gettext backend (if available at compile time)
#     # YourApp.Gettext.__locales__()
#   end
