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

  describe "color" do
    @palette ~w(#0F766E #1D4ED8 #B91C1C #A21CAF #C2410C #047857 #4338CA #BE123C)

    defp background_of(assigns), do: assigns |> render_icon() |> background()

    defp background(html) do
      case Regex.run(~r/background-color:([^;"]+);/, html) do
        [_whole, color] -> color
        nil -> nil
      end
    end

    test "defaults to a palette color, the same one for the same name" do
      first = render_icon(name: "Padaria do Ze") |> background()
      again = render_icon(name: "Padaria do Ze") |> background()

      assert first in @palette
      assert first == again
    end

    test "different names can get different palette colors, and all stay in the palette" do
      colors =
        for name <- [
              "Alpha Shop",
              "Beta Shop",
              "Gamma Shop",
              "Delta Shop",
              "Epsilon Shop",
              "Zeta"
            ] do
          render_icon(name: name) |> background()
        end

      assert Enum.all?(colors, &(&1 in @palette))
      assert length(Enum.uniq(colors)) > 1
    end

    test "uses the color the caller sends" do
      for color <- [
            "#0F766E",
            "#abc",
            "#abcd",
            "#11223344",
            "teal",
            "rebeccapurple",
            "rgb(10, 20, 30)",
            "rgba(10 20 30 / 50%)",
            "hsl(210, 50%, 40%)",
            "hsla(210deg 50% 40% / 0.5)",
            "var(--brand)",
            "RGB(10, 20, 30)",
            "  #0F766E  "
          ] do
        assert render_icon(name: "Padaria do Ze", color: color) |> background() ==
                 String.trim(color),
               "#{inspect(color)} was not used"
      end
    end

    test "a custom color replaces the palette for every name" do
      for name <- ["Alpha Shop", "Beta Shop", "Gamma Shop"] do
        assert render_icon(name: name, color: "#123456") |> background() == "#123456"
      end
    end

    test "works with merchant= and with a merchant that has no icon" do
      merchant = %MerchantIcons.Merchant{id: "shop", name: "Shop", icon: nil}

      assert render_icon(merchant: merchant, color: "navy") |> background() == "navy"
      assert background_of(merchant: merchant) in @palette
    end

    test "values that could add CSS or markup are ignored and the palette is used" do
      for color <- [
            "red;position:fixed",
            "red; background-image:url(https://example.test/x)",
            "url(https://example.test/x)",
            "#12",
            "#12345",
            "#gggggg",
            "re",
            "red blue",
            "rgb(1,2,3);color:red",
            "rgb(1,2,3) url(x)",
            "rgb(url(x))",
            "var(--x);y:z",
            "var(--x;y:z)",
            "var(--x y)",
            "var(--x'y)",
            "var(--)",
            "var(--x,fallback)",
            "rgb(1;2;3)",
            "rgb((1,2,3)",
            "rgb(1,2,3",
            "rgb()",
            "rgb(1:2)",
            "hsl(1\"2)",
            "rgb(\u00e9,2,3)",
            "#\u00e9\u00e9\u00e9",
            "var(--x) var(--y)",
            "var(x)",
            "expression(alert(1))",
            "\"onmouseover=\"x",
            "red\"><script>",
            "red'}",
            "calc(1px)",
            "",
            "   "
          ] do
        html = render_icon(name: "Padaria do Ze", color: color)

        assert background(html) in @palette, "#{inspect(color)} was not ignored"
        refute html =~ "position:fixed"
        refute html =~ "example.test"
        refute html =~ "<script"
        refute html =~ "onmouseover"
      end
    end

    test "values that are not strings are ignored" do
      for color <- [nil, 123, :red, ["red"], %{color: "red"}] do
        assert background_of(name: "Padaria do Ze", color: color) in @palette,
               "#{inspect(color)} was not ignored"
      end
    end

    test "a merchant with an icon has no colored background, so color changes nothing" do
      html = render_icon(name: "Google", color: "#123456")

      assert html =~ "<img"
      refute html =~ "background-color"
      refute html =~ "#123456"
    end

    test "a fallback svg that is used also leaves the color out" do
      html = render_icon(name: "Padaria do Ze", fallback: @valid_fallback, color: "#123456")

      assert html =~ "<img"
      refute html =~ "#123456"
    end

    test "the initial stays white whatever the background" do
      assert render_icon(name: "Padaria do Ze", color: "#FFFFFF") =~ "color:#fff"
    end
  end
end
