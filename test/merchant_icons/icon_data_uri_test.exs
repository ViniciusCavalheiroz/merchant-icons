defmodule MerchantIcons.IconDataUriTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Merchant

  @prefix "data:image/svg+xml;base64,"

  defp resolve!(description) do
    {:ok, %Merchant{} = merchant} = MerchantIcons.resolve(description)
    merchant
  end

  test "returns the base64 data URI of the bundled icon, for every bundled icon" do
    for description <- ["Google", "ADOBE", "OpenAI", "Spotify", "OpenRouter"] do
      merchant = resolve!(description)

      assert MerchantIcons.icon_data_uri(merchant) == @prefix <> Base.encode64(merchant.icon)
    end
  end

  test "the encoded icon decodes back to the exact markup" do
    merchant = resolve!("Google")
    @prefix <> encoded = MerchantIcons.icon_data_uri(merchant)

    assert Base.decode64!(encoded) == merchant.icon
  end

  test "encodes the icon of a merchant struct that is not the bundled one" do
    custom = ~s|<svg viewBox="0 0 1 1"></svg>|
    merchant = %Merchant{id: "google", name: "Google", icon: custom}

    assert MerchantIcons.icon_data_uri(merchant) == @prefix <> Base.encode64(custom)
  end

  test "an unknown id with an icon is encoded" do
    merchant = %Merchant{id: "not_bundled", name: "X", icon: "<svg viewBox=\"0 0 1 1\"></svg>"}

    assert "data:image/svg+xml;base64," <> _ = MerchantIcons.icon_data_uri(merchant)
  end

  test "returns nil for a merchant without an icon" do
    assert MerchantIcons.icon_data_uri(%Merchant{id: "shop", name: "Shop", icon: nil}) == nil
    assert MerchantIcons.icon_data_uri(resolve!("Taboola")) == nil
  end
end
