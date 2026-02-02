ExUnit.start()

# Load test support modules
Code.require_file("support/test_helpers.ex", __DIR__)

defmodule MyGettextApp do
  use Gettext.Backend, otp_app: :gettext_mapper, priv: "test/priv/gettext"
end

Application.put_env(:gettext, :default_locale, "en")
Application.put_env(:gettext_mapper, :gettext, MyGettextApp)
Application.put_env(:gettext_mapper, :supported_locales, ["en", "de", "uk"])
