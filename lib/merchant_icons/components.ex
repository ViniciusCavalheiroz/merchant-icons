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

    ## Color

    The badge shown when there is no icon (the initial of the name) takes its background color
    from a built-in palette, chosen from the name so the same name always gets the same color.
    Pass `color` to use your own:

        <.merchant_icon name="Some Shop" color="#0F766E" />
        <.merchant_icon name="Some Shop" color="rebeccapurple" />
        <.merchant_icon name="Some Shop" color="var(--brand)" />

    `color` accepts a hex color (`#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`), a color name
    (`"teal"`), `rgb()`, `rgba()`, `hsl()` or `hsla()`, and `var(--name)`. Anything else is ignored
    and the palette is used, so a value that came from a user can not add other CSS declarations
    to the element. The initial is always white; pick a color dark enough for it. A merchant that
    has an icon is not drawn on a colored background, so `color` has no effect on it.

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

    attr(:color, :string,
      default: nil,
      doc:
        "background color of the initial badge; defaults to a palette color chosen from the name"
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
        |> assign(:outer_style, outer_style(size, src, assigns.color, name))
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

    defp outer_style(size, src, color, name) do
      base =
        "display:inline-flex;align-items:center;justify-content:center;" <>
          "width:#{size}px;height:#{size}px;border-radius:9999px;overflow:hidden;"

      if is_nil(src), do: base <> "background-color:#{background_color(color, name)};", else: base
    end

    # The caller's color when it has a safe shape, otherwise the palette color for the name.
    defp background_color(color, name) do
      case safe_color(color) do
        {:ok, color} -> color
        :error -> Enum.at(@palette, :erlang.phash2(name, length(@palette)))
      end
    end

    # The value ends up inside a `style` attribute, so only shapes that cannot carry another CSS
    # declaration are accepted: no `;`, `:`, quotes or unrelated parentheses.
    defp safe_color(color) when is_binary(color) and byte_size(color) <= 100 do
      color = String.trim(color)

      if hex_color?(color) or named_color?(color) or functional_color?(color) or
           css_variable?(color),
         do: {:ok, color},
         else: :error
    end

    defp safe_color(_color), do: :error

    # `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`.
    defp hex_color?("#" <> digits),
      do: byte_size(digits) in [3, 4, 6, 8] and all_bytes?(digits, &hex_digit?/1)

    defp hex_color?(_color), do: false

    # `teal`, `rebeccapurple`, `transparent`: letters only.
    defp named_color?(name), do: byte_size(name) in 3..24 and all_bytes?(name, &letter?/1)

    # `rgb(...)`, `rgba(...)`, `hsl(...)` and `hsla(...)`. The arguments may hold numbers, units,
    # `%`, spaces, commas, `/`, `.` and `-`; there is no room for a nested function or a `;`.
    defp functional_color?(color) do
      case String.downcase(color) do
        "rgb(" <> _rest -> arguments?(color, 4)
        "rgba(" <> _rest -> arguments?(color, 5)
        "hsl(" <> _rest -> arguments?(color, 4)
        "hsla(" <> _rest -> arguments?(color, 5)
        _other -> false
      end
    end

    defp arguments?(color, prefix_size) do
      rest = binary_part(color, prefix_size, byte_size(color) - prefix_size)

      case String.ends_with?(rest, ")") do
        true ->
          inner = binary_part(rest, 0, byte_size(rest) - 1)
          byte_size(inner) in 1..60 and all_bytes?(inner, &argument_byte?/1)

        false ->
          false
      end
    end

    # `var(--brand)`: a custom property name and nothing else.
    defp css_variable?("var(--" <> rest) do
      case String.ends_with?(rest, ")") do
        true ->
          name = binary_part(rest, 0, byte_size(rest) - 1)
          byte_size(name) in 1..48 and all_bytes?(name, &name_byte?/1)

        false ->
          false
      end
    end

    defp css_variable?(_color), do: false

    # Bytes outside ASCII never satisfy these, so non-ASCII text is rejected.
    defp all_bytes?(binary, fun), do: binary |> :binary.bin_to_list() |> Enum.all?(fun)

    defp hex_digit?(byte), do: byte in ?0..?9 or byte in ?a..?f or byte in ?A..?F
    defp letter?(byte), do: byte in ?a..?z or byte in ?A..?Z
    defp digit?(byte), do: byte in ?0..?9
    defp name_byte?(byte), do: letter?(byte) or digit?(byte) or byte in [?_, ?-]

    defp argument_byte?(byte),
      do: letter?(byte) or digit?(byte) or byte in [?., ?%, ?\s, ?,, ?/, ?-]
  end
end
