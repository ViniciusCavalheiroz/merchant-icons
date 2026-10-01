defmodule MerchantIcons.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  @valid_fallback ~s|<svg viewBox="0 0 1 1" xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>|
  @invalid_fallback ~s|<svg viewBox="0 0 1 1"><script>alert(1)</script></svg>|

  defp render_icon(assigns) do
    render_component(&MerchantIcons.Components.merchant_icon/1, assigns)
  end

  test "renders a known merchant icon as an img with a base64 data URI" do
    html = render_icon(name: "Google")

    assert html =~ "<img"
    assert html =~ "src=\"data:image/svg+xml;base64,"
    refute html =~ "color:#fff"
  end

  test "defaults the img alt text to the resolved merchant name" do
    html = render_icon(name: "DL * GOOGLE A0000000123")

    assert html =~ "alt=\"Google\""
  end

  test "renders the caller fallback svg when the merchant has no icon" do
    html = render_icon(name: "Padaria do Ze", fallback: @valid_fallback)

    assert html =~ "<img"
    assert html =~ "src=\"data:image/svg+xml;base64,"
  end

  test "renders the name initial when the merchant is unknown and no fallback is given" do
    html = render_icon(name: "Padaria do Ze")

    refute html =~ "<img"
    assert html =~ ">P</span>"
  end

  test "falls back to the initial when the fallback svg is invalid" do
    html = render_icon(name: "Padaria do Ze", fallback: @invalid_fallback)

    refute html =~ "<img"
    assert html =~ ">P</span>"
  end

  test "applies the given size to the badge dimensions" do
    html = render_icon(name: "Padaria do Ze", size: 40)

    assert html =~ "width:40px;height:40px"
  end

  test "applies the given class to the outer element" do
    html = render_icon(name: "Google", class: "shadow")

    assert html =~ "class=\"shadow\""
  end

  # Handlers run in the calling process; ignore events from other concurrent tests.
  def handle_event(_event, _measurements, _metadata, parent) do
    if self() == parent, do: send(parent, :resolved)
  end

  describe "merchant attribute" do
    setup do
      {:ok, merchant} = MerchantIcons.resolve("Google")
      %{merchant: merchant}
    end

    test "renders the given merchant without resolving it", %{merchant: merchant} do
      handler = "components-test-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(handler, [:merchant_icons, :resolve], &__MODULE__.handle_event/4, parent)

      on_exit(fn -> :telemetry.detach(handler) end)

      html = render_icon(merchant: merchant)

      assert html =~ "src=\"data:image/svg+xml;base64,"
      assert html =~ "alt=\"Google\""
      refute_received :resolved
    end

    test "name still resolves when no merchant is given" do
      assert render_icon(name: "Google") =~ "alt=\"Google\""
    end

    test "merchant wins over name", %{merchant: merchant} do
      html = render_icon(merchant: merchant, name: "Padaria do Ze")

      assert html =~ "alt=\"Google\""
    end

    test "a merchant without an icon uses the fallback, then the initial" do
      merchant = %MerchantIcons.Merchant{id: "shop", name: "Shop", icon: nil}

      assert render_icon(merchant: merchant, fallback: @valid_fallback) =~ "<img"
      assert render_icon(merchant: merchant) =~ ">S</span>"
    end

    test "renders a badge when neither merchant nor name is given" do
      assert render_icon([]) =~ ">?</span>"
    end
  end

  describe "size validation" do
    test "ignores values that are not positive integers" do
      for size <- ["40", "32;position:fixed", nil, 0, -5, 3.5, :large] do
        html = render_icon(name: "Padaria do Ze", size: size)

        assert html =~ "width:32px;height:32px", "size #{inspect(size)} was not ignored"
      end
    end
  end
end
