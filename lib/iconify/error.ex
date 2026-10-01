defmodule Iconify.Error do
  @moduledoc false

  # Converts internal reasons into the public `{:error, code, message}` tuple. This is the only
  # place where messages exist.
  #
  # Messages are literals. No transaction data ever reaches a message: the only interpolated
  # value is the compile-time size limit constant. Messages are informative and not part of the
  # public contract; consumers must rely on the code.

  alias Iconify.Normalizer

  @type reason :: Normalizer.reason() | :unknown | :ambiguous

  @not_binary "transaction description must be a binary"
  @invalid_utf8 "transaction description must be valid UTF-8"
  @blank "transaction description must not be blank"
  @too_large "transaction description exceeds the maximum size of " <>
               "#{Normalizer.max_input_bytes()} bytes"
  @unknown "could not identify merchant"
  @ambiguous "multiple merchants match the transaction description"

  @spec build(reason()) :: Iconify.error()
  def build(:not_binary), do: {:error, :invalid_input, @not_binary}
  def build(:invalid_utf8), do: {:error, :invalid_input, @invalid_utf8}
  def build(:blank), do: {:error, :invalid_input, @blank}
  def build(:too_large), do: {:error, :input_too_large, @too_large}
  def build(:unknown), do: {:error, :unknown_merchant, @unknown}
  def build(:ambiguous), do: {:error, :ambiguous_merchant, @ambiguous}
end
