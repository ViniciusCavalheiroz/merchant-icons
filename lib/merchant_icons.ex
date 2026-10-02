defmodule MerchantIcons do
  @moduledoc """
  Identifies a merchant from its description and provides its icon.

  MerchantIcons only identifies merchants and returns the data an application needs to display the
  company icon. It does not deal with amounts, currencies, categories or any other financial
  data: the description is just the input used to identify the merchant.

  Descriptions are noisy: they carry codes, numbers, processor prefixes, statuses, different
  casing and accents. `resolve/1` normalizes the text and matches it against a small, static
  dataset of merchants. It works offline, keeps no state and never logs, stores or returns the
  description.

  ## Contract

  `resolve/1` returns one of:

    * `{:ok, %MerchantIcons.Merchant{}}`
    * `{:ok, :unknown}` - a valid description for which no merchant could be identified
    * `{:error, code, message}`

  An unknown merchant is not an error: it means the dataset does not cover it yet. The error
  tuple always has three elements. The `code` is the stable identifier to branch on.
  The `message` is informative English text and is not part of the contract. No message
  contains the description or any other input.

  | code                  | meaning                                                          |
  |-----------------------|------------------------------------------------------------------|
  | `:invalid_input`      | not a binary, invalid UTF-8, or empty/blank                      |
  | `:input_too_large`    | larger than the input limit (see below)                          |
  | `:ambiguous_merchant` | several merchants match and no rule picks one                    |

  The set of codes is open: new codes may be added in minor versions, so keep a clause that
  matches any `{:error, _code, _message}`.

  ## Display name

  `display_name/1` is a shortcut for the name only: it returns the merchant name (`"Google"`),
  or `nil` for an unknown merchant or an invalid description. Like `resolve/1`, it never returns
  the description, so the text to show for an unknown merchant is the caller's to choose.

  ## Icons

  `merchant.icon` holds the complete SVG markup of the merchant logo, or `nil` when the
  merchant has no icon. Handle `nil` like an unknown merchant: the application decides the
  fallback.

  The SVGs ship inside the package and are embedded when the library compiles, so getting an
  icon never touches the network or the file system. Every `viewBox` makes them scalable with
  CSS. Each file is validated at compile time: only a fixed set of SVG elements is allowed, and
  scripts, event handlers, `foreignObject`, entities and external references are rejected.

  **Render the icon as an image**, not as inline markup. Use `icon_data_uri/1` as the `src` of
  an `<img>`, or, in a Phoenix app, the ready-made `MerchantIcons.Components.merchant_icon/1`
  component, which does this and adds a fallback for merchants without an icon. An `<img>`
  cannot run scripts or load other resources, and it keeps the internal ids of the SVG isolated.
  Those ids (gradients, `clipPath`, filters, referenced with `url(#id)`) collide when the same
  icon is inlined more than once on a page - a list, or LiveView, which keeps a server and a
  client copy of the DOM - and the references stop painting.

  A `data:` URI in `<img src>` needs `data:` in the `img-src` directive of your
  Content-Security-Policy when the application sets one (for example
  `img-src 'self' data:`).

  ## Telemetry

  `resolve/1` emits one `:telemetry` event when it identifies a merchant or concludes that the
  merchant is unknown:

    * event: `[:merchant_icons, :resolve]`
    * measurements: `%{count: 1}`
    * metadata: `%{result: :merchant_resolved}` or `%{result: :merchant_unknown}`

  The event never carries the description, the merchant or any other input. Validation errors
  (`:invalid_input`, `:input_too_large`) and `:ambiguous_merchant` do not emit events in this
  version. The library does not log, store or aggregate anything: the application decides
  whether to attach a handler. Without a handler, `resolve/1` behaves the same.

  ## Input handling

  Every description is treated as untrusted data. `resolve/1` never raises because of its input.
  Descriptions larger than #{MerchantIcons.Matching.Normalizer.max_input_bytes()} bytes are rejected, not
  truncated. This limit is provisional and may change before the first release.

  ## Matching

  Descriptions are normalized (Unicode NFKD, accents removed, case folded, zero-width characters
  removed) and split into tokens at separators and at letter/digit boundaries. CamelCase is not
  split. A processor prefix (`dl`, `dm`, `ebn`, `ppro`, `dlocal` or `ebanx`) at the start of the
  description is ignored. Aliases are token sequences and come in two kinds:

    * `:whole` - the alias must account for the whole description. Only digits-only tokens
      may follow it.
    * `:leading` - the alias must start the description. Anything may follow it.

  The alias with more tokens wins, then `:whole` wins over `:leading`. If different merchants
  remain, the result is `:ambiguous_merchant`. There is no substring matching.
  """

  alias MerchantIcons.Data.Merchants
  alias MerchantIcons.Error
  alias MerchantIcons.Icons
  alias MerchantIcons.Matching.Index
  alias MerchantIcons.Matching.Matcher
  alias MerchantIcons.Matching.Normalizer
  alias MerchantIcons.Merchant

  @typedoc """
  Stable identifier of an error. The set of codes is open to additions in minor versions.
  """
  @type error_code ::
          :invalid_input | :input_too_large | :ambiguous_merchant

  @typedoc """
  Error tuple returned by `resolve/1`. The second element is the stable code and the third is
  an informative message that is not part of the contract.
  """
  @type error :: {:error, error_code(), String.t()}

  @icons_dir Path.expand("../priv/icons", __DIR__)

  # Recompile when an icon file changes, so the embedded markup is never stale.
  for path <- Icons.files(@icons_dir) do
    @external_resource path
  end

  @merchants Icons.embed!(Merchants.all(), @icons_dir)

  @index Index.build(@merchants)

  # Data URIs of the bundled icons, encoded once while the library compiles. The icon is kept
  # next to its URI so `icon_data_uri/1` only returns the precomputed value for the exact
  # bundled markup and still encodes a merchant struct built with any other icon.
  @data_uris for %{id: id, icon: icon} <- @merchants,
                 is_binary(icon),
                 into: %{},
                 do: {id, {icon, "data:image/svg+xml;base64," <> Base.encode64(icon)}}

  @doc """
  Resolves a transaction description to a merchant.

  Accepts any term. Anything that is not a valid, non-blank UTF-8 binary within the size limit
  is reported as an error tuple instead of raising.

  ## Examples

      iex> {:ok, merchant} = MerchantIcons.resolve("Google ADS1234567890")
      iex> {merchant.id, merchant.name}
      {"google", "Google"}

      iex> {:ok, merchant} = MerchantIcons.resolve("ADOBE")
      iex> {merchant.id, merchant.name}
      {"adobe", "Adobe"}

      iex> MerchantIcons.resolve("PADARIA DO ZE 0042")
      {:ok, :unknown}

      iex> {:error, :invalid_input, message} = MerchantIcons.resolve("   ")
      iex> is_binary(message)
      true

      iex> {:error, :invalid_input, message} = MerchantIcons.resolve(nil)
      iex> is_binary(message)
      true

  Works naturally with pattern matching. Branch on the code, never on the message:

      iex> case MerchantIcons.resolve("ADOBE 12345") do
      ...>   {:ok, :unknown} -> nil
      ...>   {:ok, merchant} -> merchant.name
      ...>   {:error, _code, _message} -> nil
      ...> end
      "Adobe"

  """
  @spec resolve(term()) :: {:ok, Merchant.t()} | {:ok, :unknown} | error()
  def resolve(description) do
    description
    |> Normalizer.tokens()
    |> match_merchant()
    |> build_result()
    |> emit_telemetry()
  end

  @doc """
  Returns the display name of the merchant a description resolves to, or `nil`.

  It resolves the description with `resolve/1` and returns the `name` of the merchant, for
  example `"Google"`. Anything else returns `nil`: a description that matches no merchant
  (`{:ok, :unknown}`), an ambiguous one, and any invalid term. It accepts any term and never
  raises.

  The description is never returned, not even in a cleaned-up form. When this returns `nil`,
  choosing what to show for the unknown merchant is up to the caller.

  ## Examples

      iex> MerchantIcons.display_name("DL * GOOGLE A0000000123")
      "Google"

      iex> MerchantIcons.display_name("PADARIA DO ZE 0042")
      nil

      iex> MerchantIcons.display_name(nil)
      nil

  """
  @spec display_name(term()) :: String.t() | nil
  def display_name(description) do
    case resolve(description) do
      {:ok, %Merchant{name: name}} -> name
      _unknown_or_error -> nil
    end
  end

  @doc """
  Returns the merchant icon as a `data:` URI, or `nil` when the merchant has no icon.

  Use it as the `src` of an `<img>` when the icon is rendered more than once on a page (a list,
  or a server/client DOM like Phoenix LiveView). Rendering it as an image scopes the icon's
  internal ids (gradients, `clipPath`, filters) inside the image's own document, so repeated
  icons no longer collide on `url(#id)` references the way inlined markup does.

  The URI of every bundled icon is built when the library compiles, so for a merchant returned by
  `resolve/1` this is a lookup, not an encoding. The application's Content-Security-Policy needs
  `data:` in `img-src` when it sets one.

  ## Examples

      iex> {:ok, merchant} = MerchantIcons.resolve("Google")
      iex> "data:image/svg+xml;base64," <> _ = MerchantIcons.icon_data_uri(merchant)

      iex> MerchantIcons.icon_data_uri(%MerchantIcons.Merchant{id: "x", name: "X", icon: nil})
      nil

  """
  @spec icon_data_uri(Merchant.t()) :: String.t() | nil
  def icon_data_uri(%Merchant{id: id, icon: icon}) when is_binary(icon) do
    case @data_uris do
      %{^id => {^icon, data_uri}} -> data_uri
      _other -> "data:image/svg+xml;base64," <> Base.encode64(icon)
    end
  end

  def icon_data_uri(%Merchant{}), do: nil

  defp match_merchant({:error, _reason} = error), do: error
  defp match_merchant({:ok, tokens}), do: Matcher.match(tokens, @index)

  defp build_result({:ok, %Merchant{}} = result), do: result
  defp build_result({:error, :unknown}), do: {:ok, :unknown}
  defp build_result({:error, reason}), do: Error.build(reason)

  # Metadata is a fixed atom: the description never reaches the event.
  defp emit_telemetry({:ok, %Merchant{}} = result), do: emit(:merchant_resolved, result)
  defp emit_telemetry({:ok, :unknown} = result), do: emit(:merchant_unknown, result)

  defp emit_telemetry(result), do: result

  defp emit(outcome, result) do
    :telemetry.execute([:merchant_icons, :resolve], %{count: 1}, %{result: outcome})
    result
  end
end
