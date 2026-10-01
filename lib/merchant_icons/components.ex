# Compiled only when Phoenix.Component is available (phoenix_live_view is an optional
# dependency). Projects that use MerchantIcons purely as a resolver never pull Phoenix in.
if Code.ensure_loaded?(Phoenix.Component) do
  defmodule MerchantIcons.Components do
    @moduledoc """
    Phoenix function components for rendering merchant icons.

    `import MerchantIcons.Components` in the module that renders, then call
    `merchant_icon/1` with the raw merchant description. The component resolves the
    merchant, renders its icon as an isolated `<img>` (a `data:` URI, so the icon's
    internal ids never collide in the page DOM — see `MerchantIcons`), and falls back
    gracefully when there is no icon.

    ## Fallback order

      1. the merchant's bundled icon, when the description resolves to one;
      2. the `fallback` SVG markup given by the caller, when it is valid;
      3. a badge with the first letter of the merchant/description name.

    ## Examples

        <.merchant_icon name={@transaction.merchant_name} />
        <.merchant_icon name="Some Shop" size={40} class="shadow" />
        <.merchant_icon name="Unknown LTDA" fallback={@store_svg} />
    """

    use Phoenix.Component

    alias MerchantIcons.Icons
    alias MerchantIcons.Merchant

    # Deterministic badge backgrounds for the initial fallback.
    @palette ~w(#0F766E #1D4ED8 #B91C1C #A21CAF #C2410C #047857 #4338CA #BE123C)

    attr :name, :string, required: true, doc: "raw merchant description/name to resolve"

    attr :fallback, :string,
      default: nil,
      doc: "SVG markup to render when the merchant has no bundled icon"

    attr :size, :integer, default: 32, doc: "badge size in pixels"
    attr :class, :string, default: nil, doc: "extra classes for the outer element"
    attr :alt, :string, default: nil, doc: "image alt text; defaults to the merchant name"
    attr :rest, :global

    @doc "Renders the icon of the merchant resolved from `name` as a self-contained badge."
    def merchant_icon(assigns) do
      merchant = resolve(assigns.name)
      name = display_name(merchant, assigns.name)
      src = icon_src(merchant, assigns.fallback)

      assigns =
        assigns
        |> assign(:src, src)
        |> assign(:alt, assigns.alt || name)
        |> assign(:initial, initial(name))
        |> assign(:outer_style, outer_style(assigns.size, src, name))
        |> assign(:image_style, "width:#{round(assigns.size * 0.72)}px;height:#{round(assigns.size * 0.72)}px;object-fit:contain;")
        |> assign(:initial_style, "color:#fff;font-weight:600;line-height:1;font-size:#{round(assigns.size * 0.42)}px;")

      ~H"""
      <span class={@class} style={@outer_style} {@rest}>
        <img :if={@src} src={@src} alt={@alt} style={@image_style} />
        <span :if={is_nil(@src)} style={@initial_style}>{@initial}</span>
      </span>
      """
    end

    defp resolve(name) do
      case MerchantIcons.resolve(name) do
        {:ok, %Merchant{} = merchant} -> merchant
        _other -> nil
      end
    end

    defp icon_src(%Merchant{icon: icon}, _fallback) when is_binary(icon), do: to_data_uri(icon)

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
