defmodule Iconify do
  @moduledoc """
  Identifies the merchant behind a financial transaction description and provides its icon.

  Iconify only identifies merchants and returns the data an application needs to display the
  company icon. It does not deal with amounts, currencies, categories or any other financial
  data: the description is just the input used to identify the merchant.

  Descriptions are noisy: they carry codes, numbers, processor prefixes, statuses, different
  casing and accents. `resolve/1` normalizes the text and matches it against a small, static
  dataset of merchants. It works offline, keeps no state and never logs, stores or returns the
  description.

  ## Contract

  `resolve/1` returns one of:

    * `{:ok, %Iconify.Merchant{}}`
    * `{:error, code, message}`

  The error tuple always has three elements. The `code` is the stable identifier to branch on.
  The `message` is informative English text and is not part of the contract. No message
  contains the description or any other input.

  | code                  | meaning                                                          |
  |-----------------------|------------------------------------------------------------------|
  | `:invalid_input`      | not a binary, invalid UTF-8, or empty/blank                      |
  | `:input_too_large`    | larger than the input limit (see below)                          |
  | `:unknown_merchant`   | valid description, no merchant could be identified               |
  | `:ambiguous_merchant` | several merchants match and no rule picks one                    |

  The set of codes is open: new codes may be added in minor versions, so keep a clause that
  matches any `{:error, _code, _message}`.

  ## Icons

  `merchant.icon` holds the complete SVG markup of the merchant logo, or `nil` when the
  merchant has no icon. Handle `nil` like an unknown merchant: the application decides the
  fallback.

  The SVGs ship inside the package and are embedded when the library compiles, so getting an
  icon never touches the network or the file system. The markup is meant to be inlined in HTML
  and scaled with CSS (every icon has a `viewBox`). Each file is validated at compile time:
  scripts, event handlers, `foreignObject`, entities and external references are rejected.

  ## Input handling

  Every description is treated as untrusted data. `resolve/1` never raises because of its input.
  Descriptions larger than #{Iconify.Normalizer.max_input_bytes()} bytes are rejected, not
  truncated. This limit is provisional and may change before the first release.

  ## Matching

  Descriptions are normalized (Unicode NFKD, accents removed, case folded, zero-width characters
  removed) and split into tokens at separators and at letter/digit boundaries. CamelCase is not
  split. A processor prefix (`dl`, `dm`, `ebn` or `ppro`) at the start of the description is
  ignored. Aliases are token sequences and come in two kinds:

    * `:whole` - the alias must account for the whole description. Only digits-only tokens
      may follow it.
    * `:leading` - the alias must start the description. Anything may follow it.

  The alias with more tokens wins, then `:whole` wins over `:leading`. If different merchants
  remain, the result is `:ambiguous_merchant`. There is no substring matching.
  """

  alias Iconify.Error
  alias Iconify.Icons
  alias Iconify.Index
  alias Iconify.Matcher
  alias Iconify.Merchant
  alias Iconify.Merchants
  alias Iconify.Normalizer

  @typedoc """
  Stable identifier of an error. The set of codes is open to additions in minor versions.
  """
  @type error_code ::
          :invalid_input | :input_too_large | :unknown_merchant | :ambiguous_merchant

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

  @index Index.build(Icons.embed!(Merchants.all(), @icons_dir))

  @doc """
  Resolves a transaction description to a merchant.

  Accepts any term. Anything that is not a valid, non-blank UTF-8 binary within the size limit
  is reported as an error tuple instead of raising.

  ## Examples

      iex> {:ok, merchant} = Iconify.resolve("Google ADS2397919998")
      iex> {merchant.id, merchant.name}
      {"google", "Google"}

      iex> {:ok, merchant} = Iconify.resolve("ADOBE")
      iex> {merchant.id, merchant.name}
      {"adobe", "Adobe"}

      iex> {:error, :unknown_merchant, message} = Iconify.resolve("PADARIA DO ZE 0042")
      iex> is_binary(message)
      true

      iex> {:error, :invalid_input, message} = Iconify.resolve("   ")
      iex> is_binary(message)
      true

      iex> {:error, :invalid_input, message} = Iconify.resolve(nil)
      iex> is_binary(message)
      true

  Works naturally with pattern matching. Branch on the code, never on the message:

      iex> case Iconify.resolve("ADOBE 12345") do
      ...>   {:ok, merchant} -> merchant.name
      ...>   {:error, :unknown_merchant, _message} -> nil
      ...>   {:error, _code, _message} -> nil
      ...> end
      "Adobe"

  """
  @spec resolve(term()) :: {:ok, Merchant.t()} | error()
  def resolve(description) do
    description
    |> Normalizer.tokens()
    |> match_merchant()
    |> build_result()
  end

  defp match_merchant({:error, _reason} = error), do: error
  defp match_merchant({:ok, tokens}), do: Matcher.match(tokens, @index)

  defp build_result({:ok, %Merchant{}} = result), do: result
  defp build_result({:error, reason}), do: Error.build(reason)
end
