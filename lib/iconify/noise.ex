defmodule Iconify.Noise do
  @moduledoc false

  # Noise rules used by the matcher.
  #
  # Processor prefixes are tokens that, at the start of a description, precede the merchant
  # (`<prefix> * <merchant> ...`). Only tokens that consistently precede many unrelated merchants
  # in observed descriptors are listed. A short or frequent token is not a prefix by itself: a
  # token that is also a merchant or a processor entity in its own right (for example a payment
  # service name) must not be added without an explicit decision, because skipping it would make
  # the description unresolvable.
  #
  # Digits-only tokens are structural noise (no vocabulary involved): after a `:whole` alias
  # they are ignored by the matcher.

  @prefixes ["dl", "dm", "ebn", "ppro"]

  @doc "Processor prefix tokens recognised at the start of a description (production)."
  @spec prefixes() :: [String.t()]
  def prefixes, do: @prefixes

  @doc "True when the token is non-empty and made only of ASCII digits."
  @spec digits_only?(String.t()) :: boolean()
  def digits_only?(""), do: false

  def digits_only?(token) when is_binary(token) do
    token
    |> :binary.bin_to_list()
    |> Enum.all?(&(&1 in ?0..?9))
  end
end
