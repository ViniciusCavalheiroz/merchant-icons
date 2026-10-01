defmodule Iconify.PropertiesTest do
  use ExUnit.Case, async: true

  # Property-style tests using only the standard library: inputs come from a seeded random
  # generator, so every run is deterministic and reproducible. StreamData would add shrinking
  # and better generators; adding it is a separate decision.
  #
  # Invisible and ambiguous characters are always written as \u{...} escapes in this file.

  alias Iconify.Merchant
  alias Iconify.Normalizer
  alias Iconify.Test.Support.Corpus

  @iterations 300
  @codes [:invalid_input, :input_too_large, :unknown_merchant, :ambiguous_merchant]

  setup do
    :rand.seed(:exsss, {101, 202, 303})
    :ok
  end

  defp assert_contract(result) do
    case result do
      {:ok, %Merchant{}} ->
        :ok

      {:error, code, message} when code in @codes and is_binary(message) ->
        assert message != ""
    end
  end

  defp random_codepoint do
    codepoint =
      case :rand.uniform(6) do
        1 -> Enum.random(?a..?z)
        2 -> Enum.random(?0..?9)
        3 -> Enum.random(0x00..0x7F)
        4 -> Enum.random(0x80..0x24FF)
        5 -> Enum.random(0x2500..0xFFFD)
        6 -> Enum.random(0x10000..0x1FBFF)
      end

    # Surrogates are not valid scalar values in UTF-8.
    if codepoint in 0xD800..0xDFFF, do: ?a, else: codepoint
  end

  defp random_unicode_string do
    for _ <- List.duplicate(nil, :rand.uniform(40) - 1), into: "" do
      <<random_codepoint()::utf8>>
    end
  end

  defp random_ascii_string do
    for _ <- List.duplicate(nil, :rand.uniform(60) - 1), into: "" do
      <<Enum.random(0x20..0x7E)>>
    end
  end

  defp random_digits do
    for _ <- List.duplicate(nil, :rand.uniform(12)), into: "" do
      <<Enum.random(?0..?9)>>
    end
  end

  test "arbitrary binaries never raise and always respect the contract" do
    for _ <- 1..@iterations do
      assert_contract(Iconify.resolve(:rand.bytes(:rand.uniform(1_200) - 1)))
    end
  end

  test "arbitrary Unicode strings never raise and always respect the contract" do
    for _ <- 1..@iterations do
      assert_contract(Iconify.resolve(random_unicode_string()))
    end
  end

  test "normalization is deterministic, never yields empty tokens, and is idempotent" do
    for _ <- 1..@iterations do
      input = random_unicode_string()

      assert Normalizer.tokens(input) == Normalizer.tokens(input)

      case Normalizer.tokens(input) do
        {:ok, []} ->
          :ok

        {:ok, tokens} ->
          assert Enum.all?(tokens, &(&1 != ""))

          assert Normalizer.tokens(Enum.join(tokens, " ")) == {:ok, tokens},
                 "not idempotent for #{inspect(input)}"

        {:error, :blank} ->
          :ok
      end
    end
  end

  test "ASCII input is insensitive to letter case" do
    for _ <- 1..@iterations do
      input = random_ascii_string()

      assert Normalizer.tokens(String.upcase(input)) ==
               Normalizer.tokens(String.downcase(input))

      assert Iconify.resolve(String.upcase(input)) == Iconify.resolve(String.downcase(input))
    end
  end

  test "trailing digits-only tokens never change a resolved merchant" do
    for {description, id} <- Corpus.resolving(), _ <- 1..20 do
      assert {:ok, %Merchant{id: ^id}} = Iconify.resolve(description <> " " <> random_digits())
    end
  end

  test "trailing digits-only tokens never turn an unknown description into a merchant" do
    for description <- Corpus.unknown(), _ <- 1..20 do
      assert {:error, :unknown_merchant, _} =
               Iconify.resolve(description <> " " <> random_digits())
    end
  end

  test "extra whitespace and control characters never change the result" do
    for {description, _id} <- Corpus.resolving() do
      expected = Iconify.resolve(description)

      assert Iconify.resolve(String.replace(description, " ", "  \t ")) == expected
      assert Iconify.resolve("  " <> description <> "\n") == expected
      assert Iconify.resolve(String.replace(description, " ", "\u{A0}")) == expected
    end
  end
end
