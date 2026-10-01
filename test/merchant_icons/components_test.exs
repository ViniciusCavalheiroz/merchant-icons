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
end
