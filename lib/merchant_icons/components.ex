# Compiled only when Phoenix.Component is available (phoenix_live_view is an optional
# dependency). Projects that use MerchantIcons purely as a resolver never pull Phoenix in.
if Code.ensure_loaded?(Phoenix.Component) do
  defmodule MerchantIcons.Components do
    @moduledoc """
    Phoenix function components for rendering merchant icons.

    `import MerchantIcons.Components` in the module that renders, then call
    `merchant_icon/1` with the raw merchant description (`name`) or with a merchant you already
    resolved (`merchant`). The component resolves the description, renders the icon as an
    isolated `<img>` (a `data:` URI, so the icon's internal ids never collide in the page DOM —
    see `MerchantIcons`), and falls back gracefully when there is no icon.

    ## Fallback order

      1. the merchant's bundled icon, when the description resolves to one;
      2. the `fallback` SVG markup given by the caller, when it is valid;
      3. a badge with the first letter of the merchant/description name.

    ## Resolving once

    `name` is resolved on every render. For lists, resolve when the data is loaded or stored and
    pass the `%MerchantIcons.Merchant{}` through `merchant`: no resolve happens then, and no
    `[:merchant_icons, :resolve]` telemetry event is emitted. When both are given, `merchant`
    wins and `name` is only used as the badge text for a merchant without an icon.

    ## Size

    `size` must be a positive integer (pixels). Anything else is ignored and the default of 32 is
    used, so a bad value never crashes the render.

    ## Examples

        <.merchant_icon name={@transaction.merchant_name} />
        <.merchant_icon merchant={@transaction.merchant} />
        <.merchant_icon name="Some Shop" size={40} class="shadow" />
        <.merchant_icon name="Unknown LTDA" fallback={@store_svg} />
    """

    use Phoenix.Component

    alias MerchantIcons.Icons
    alias MerchantIcons.Merchant

    @default_size 32

    # Deterministic badge backgrounds for the initial fallback.
    @palette ~w(#0F766E #1D4ED8 #B91C1C #A21CAF #C2410C #047857 #4338CA #BE123C)

    attr(:name, :string,
      default: nil,
      doc: "raw merchant description/name to resolve; not needed when `merchant` is given"
    )

    attr(:merchant, :any,
      default: nil,
      doc: "an already resolved `%MerchantIcons.Merchant{}`; skips the resolve"
    )

    attr(:fallback, :string,
      default: nil,
      doc: "SVG markup to render when the merchant has no bundled icon"
    )

    attr(:size, :integer,
      default: @default_size,
      doc: "badge size in pixels (positive integer, otherwise #{@default_size})"
    )

    attr(:class, :string, default: nil, doc: "extra classes for the outer element")
    attr(:alt, :string, default: nil, doc: "image alt text; defaults to the merchant name")
    attr(:rest, :global)

    @doc "Renders the icon of the merchant resolved from `name` as a self-contained badge."
    def merchant_icon(assigns) do
      merchant = merchant(assigns.merchant, assigns.name)
      name = display_name(merchant, assigns.name)
      src = icon_src(merchant, assigns.fallback)
      size = valid_size(assigns.size)

      assigns =
        assigns
        |> assign(:src, src)
        |> assign(:alt, assigns.alt || name)
        |> assign(:initial, initial(name))
        |> assign(:outer_style, outer_style(size, src, name))
        |> assign(
          :image_style,
          "width:#{round(size * 0.72)}px;height:#{round(size * 0.72)}px;object-fit:contain;"
        )
        |> assign(
          :initial_style,
          "color:#fff;font-weight:600;line-height:1;font-size:#{round(size * 0.42)}px;"
        )

      ~H"""
      <span class={@class} style={@outer_style} {@rest}>
        <img :if={@src} src={@src} alt={@alt} style={@image_style} />
        <span :if={is_nil(@src)} style={@initial_style}>{@initial}</span>
      </span>
      """
    end

    defp valid_size(size) when is_integer(size) and size > 0, do: size
    defp valid_size(_size), do: @default_size

    # A resolved merchant is used as given; otherwise the description is resolved.
    defp merchant(%Merchant{} = merchant, _name), do: merchant
    defp merchant(_other, name), do: resolve(name)

    defp resolve(name) do
      case MerchantIcons.resolve(name) do
        {:ok, %Merchant{} = merchant} -> merchant
        _other -> nil
      end
    end

    defp icon_src(%Merchant{icon: icon} = merchant, _fallback) when is_binary(icon),
      do: MerchantIcons.icon_data_uri(merchant)

    defp icon_src(_merchant, fallback) when is_binary(fallback) do
      case Icons.validate(fallback) do
        {:ok, svg} -> to_data_uri(svg)
        {:error, _reason} -> nil
      end
    end

    defp icon_src(_merchant, _fallback), do: nil

    defp to_data_uri(svg), do: "data:image/svg+xml;base64," <> Base.encode64(svg)

    defp display_name(%Merchant{name: name}, _input) when is_binary(name) and name != "", do: name
    defp display_name(_merchant, input) when is_binary(input), do: input
    defp display_name(_merchant, _input), do: ""

    defp initial(name) do
      case name |> String.trim() |> String.first() do
        nil -> "?"
        char -> String.upcase(char)
      end
    end

    defp outer_style(size, src, name) do
      base =
        "display:inline-flex;align-items:center;justify-content:center;" <>
          "width:#{size}px;height:#{size}px;border-radius:9999px;overflow:hidden;"

      if is_nil(src), do: base <> "background-color:#{bg_color(name)};", else: base
    end

    defp bg_color(name), do: Enum.at(@palette, :erlang.phash2(name, length(@palette)))
  end
end
