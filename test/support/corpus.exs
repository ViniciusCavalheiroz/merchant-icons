defmodule Iconify.Test.Support.Corpus do
  @moduledoc false

  # Synthetic descriptions. None of them comes from a real transaction: codes and suffixes are
  # made up. The shapes are illustrative of the behaviour under test, not claims about how any
  # processor or merchant really formats descriptions.

  @doc "Descriptions that resolve in production, with the expected merchant id."
  def resolving do
    [
      {"Google ADS2397919998", "google"},
      {"Google ADS8415026549", "google"},
      {"GOOGLE ADS 123", "google"},
      {"google", "google"},
      {"Google One", "google_one"},
      {"Google TEMPORARY HOLD", "google"},
      {"DL * GOOGLE ADS84150265", "google"},
      {"DL * UberRides", "uber"},
      {"Uber UBER * PENDING", "uber"},
      {"Uber Trip Help", "uber"},
      {"UBER", "uber"},
      {"UberRides", "uber"},
      {"UBERRIDES 12345", "uber"},
      {"ADOBE", "adobe"},
      {"adobe 12345", "adobe"},
      {"ADOBE * ADOBE", "adobe"},
      {"PPRO * ADOBE", "adobe"},
      {"EBN * ADOBE", "adobe"},
      {"DM * Slack T000AAA0000", "slack"},
      {"FACEBK * AB12CD34EF", "facebook"},
      {"FACEBK * TEMP HOLD ZZZZ", "facebook"},
      {"Microsoft-G000000001", "microsoft"},
      {"ANTHROPIC * CLAUDE TEAM", "anthropic"},
      {"CLAUDE.AI SUBSCRIPTION", "claude"},
      {"Amazon Web Services", "aws"},
      {"AMAZON AWS SERVICES XX", "aws"},
      {"Amazon Marketplace", "amazon"},
      {"MANYCHAT.COM * TRIAL OVER", "manychat"},
      {"1PASSWORD", "1password"},
      {"NRI * NEW RELIC", "new_relic"},
      {"WWW CONTABO COM", "contabo"},
      {"MERCADO * MERCADOLIVRE", "mercado_livre"}
    ]
  end

  @doc """
  Descriptions that must stay unknown in production: false-positive guards and documented
  limitations of the conservative matching.
  """
  def unknown do
    [
      # token boundaries: no substring or character-prefix matching
      "UBERABA MATERIAIS",
      # aliases are anchored at the start of the description
      "SUPER UBER",
      "MY GOOGLE ADS",
      "NOT ADOBE",
      # a leading token that is not an approved processor prefix is not skipped
      "XY * GOOGLE ADS84150265",
      "PAYPAL * GITHUB INC",
      # documented limitation: names glued to other letters are not matched
      "GOOGLEADS123",
      "DM * hostingercomxx",
      # a :whole alias does not tolerate extra words
      "UberRides Trip",
      "UI KIT STORE",
      "GATHER ROUND CAFE",
      "SENTRY SECURITY",
      "CURSOR SERVICOS",
      "FINGERPRINT STUDIO",
      # short or generic words are not aliases of a merchant
      "MEGA SUPERMERCADO",
      "HEX MARKET",
      "CLAUDE RODRIGUES",
      "MERCADO CENTRAL",
      # digit-bearing names are not truncated into a different merchant
      "C6 BANK",
      "7ELEVEN",
      "PADARIA DO ZE 0042"
    ]
  end
end
