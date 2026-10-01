defmodule MerchantIcons.Error do
  @moduledoc false

  # Converts internal reasons into the public `{:error, code, message}` tuple. This is the only
  # place where messages exist.
  #
  # Messages are literals. No input data ever reaches a message: the only interpolated
  # value is the compile-time size limit constant. Messages are informative and not part of the
  # public contract; consumers must rely on the code.

  alias MerchantIcons.Matching.Normalizer

  @type reason :: Normalizer.reason() | :ambiguous

  @not_binary "merchant description must be a binary"
  @invalid_utf8 "merchant description must be valid UTF-8"
  @blank "merchant description must not be blank"
  @too_large "merchant description exceeds the maximum size of " <>
               "#{Normalizer.max_input_bytes()} bytes"
  @ambiguous "multiple merchants match the description"

  @spec build(reason()) :: MerchantIcons.error()
  def build(:not_binary), do: {:error, :invalid_input, @not_binary}
  def build(:invalid_utf8), do: {:error, :invalid_input, @invalid_utf8}
  def build(:blank), do: {:error, :invalid_input, @blank}
  def build(:too_large), do: {:error, :input_too_large, @too_large}
  def build(:ambiguous), do: {:error, :ambiguous_merchant, @ambiguous}
end
