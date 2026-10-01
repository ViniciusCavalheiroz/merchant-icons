defmodule MerchantIcons.Data.MerchantsTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Data.Merchants
  alias MerchantIcons.Icons
  alias MerchantIcons.Matching.Index
  alias MerchantIcons.Merchant

  @icons_dir Path.expand("../../../priv/icons", __DIR__)

  defp resolved_id(description) do
    case MerchantIcons.resolve(description) do
      {:ok, %Merchant{id: id}} -> id
      {:ok, :unknown} -> :unknown
      {:error, code, _message} -> code
    end
  end

  test "the production dataset is valid" do
    assert %Index{} = Index.build(Merchants.all())
  end

  test "icon references and icon files are consistent" do
    # Raises when a referenced file is missing or invalid, or when a file has no merchant.
    assert is_list(Icons.embed!(Merchants.all(), @icons_dir))
  end

  test "merchant ids are unique and include the core merchants" do
    ids = Enum.map(Merchants.all(), & &1.id)

    assert ids == Enum.uniq(ids)

    for id <- ["google", "uber", "adobe", "amazon", "aws", "facebook", "google_one", "claude"] do
      assert id in ids
    end
  end

  test ":whole aliases are pinned: they change the matching surface" do
    whole =
      for %{id: id, aliases: aliases} <- Merchants.all(), {text, :whole} <- aliases do
        {id, text}
      end

    assert Enum.sort(whole) == [
             {"cursor", "cursor"},
             {"fingerprint", "fingerprint"},
             {"gather", "gather"},
             {"miro", "miro"},
             {"readme", "readme"},
             {"sentry", "sentry"},
             {"uber", "uberrides"},
             {"ui", "ui"},
             {"ui", "www ui com"}
           ]
  end

  test "every alias resolves to its own merchant" do
    # This also catches aliases shared between merchants (ambiguous) and unreachable aliases.
    for %{id: id, name: name, aliases: aliases} <- Merchants.all(),
        {alias_text, _kind} <- aliases do
      assert {:ok, %Merchant{id: ^id, name: ^name}} = MerchantIcons.resolve(alias_text),
             "alias #{inspect(alias_text)} does not resolve to #{id}"
    end
  end

  test "every resolved merchant carries validated SVG markup or nil" do
    for %{aliases: aliases} <- Merchants.all(), {alias_text, _kind} <- aliases do
      {:ok, %Merchant{icon: icon}} = MerchantIcons.resolve(alias_text)

      assert is_nil(icon) or Icons.validate(icon) == {:ok, icon}
    end
  end

  test "processor prefixes dl, dm, ebn and ppro are skipped at the start" do
    for prefix <- ["dl", "DM", "Ebn", "PPRO"] do
      assert resolved_id("#{prefix} * Google") == "google"
    end
  end

  test "other leading tokens are not processor prefixes" do
    for prefix <- ["PAYPAL", "EB", "PG", "EC", "XY"] do
      assert resolved_id("#{prefix} * Google") == :unknown
    end
  end

  test "amazon retail and AWS are different merchants" do
    assert resolved_id("Amazon Web Services") == "aws"
    assert resolved_id("Amazon AWS Services XX") == "aws"
    assert resolved_id("Amazon Marketplace") == "amazon"
    assert resolved_id("Amazon BR") == "amazon"
  end

  test "a longer alias wins over a shorter one" do
    assert resolved_id("Google One") == "google_one"
    assert resolved_id("Google ADS 123") == "google"
    assert resolved_id("DL * Google Google One") == "google"
  end

  test "FACEBK and FACEBOOK are the same merchant" do
    descriptions = [
      "FACEBK",
      "FACEBOOK",
      "facebk",
      "Facebook Ads",
      "FACEBK * AB12CD34EF",
      "FACEBOOK * TEMP HOLD ZZZZ"
    ]

    for description <- descriptions do
      assert resolved_id(description) == "facebook",
             "expected #{inspect(description)} to resolve to facebook"
    end

    assert MerchantIcons.resolve("FACEBK") == MerchantIcons.resolve("FACEBOOK")
  end

  test "anthropic and claude are different merchants" do
    assert resolved_id("ANTHROPIC CLAUDE TEAM") == "anthropic"
    assert resolved_id("Claude.ai Subscription") == "claude"
  end

  test "digits-only tokens are ignored after a :whole alias, other tokens are not" do
    assert resolved_id("UBERRIDES 12345") == "uber"
    assert resolved_id("UBERRIDES 12X") == :unknown
  end

  test "numbers can be part of an alias" do
    assert resolved_id("1PASSWORD") == "1password"
    assert resolved_id("1Password Team 5") == "1password"
  end
end
