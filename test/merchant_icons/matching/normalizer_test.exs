defmodule MerchantIcons.Matching.NormalizerTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Matching.Normalizer
  alias MerchantIcons.Test.Helpers.Corpus

  defp assert_tokens(cases) do
    for {input, expected} <- cases do
      assert Normalizer.tokens(input) == {:ok, expected},
             "unexpected tokens for #{inspect(input)}"
    end
  end

  describe "tokens/1 examples" do
    test "the documented descriptions" do
      assert_tokens([
        {"DL * GOOGLE A0000021232", ["dl", "google", "a", "0000021232"]},
        {"Google ADS2397919998", ["google", "ads", "2397919998"]},
        {"Google A000002123249", ["google", "a", "000002123249"]},
        {"Uber UBER * PENDING", ["uber", "uber", "pending"]},
        {"DL * UberRides", ["dl", "uberrides"]},
        {"ADOBE", ["adobe"]}
      ])
    end

    test "camelCase is not split, so case never changes the result" do
      assert Normalizer.tokens("UberRides") == Normalizer.tokens("UBERRIDES")
      assert Normalizer.tokens("UberRides") == {:ok, ["uberrides"]}
    end

    test "letter/digit boundaries split tokens, digits are never deleted" do
      assert_tokens([
        {"C6 BANK", ["c", "6", "bank"]},
        {"C6BANK", ["c", "6", "bank"]},
        {"7ELEVEN", ["7", "eleven"]},
        {"0042", ["0042"]},
        {"A0000021232", ["a", "0000021232"]}
      ])
    end

    test "punctuation and symbols separate tokens" do
      assert_tokens([
        {"AT&T", ["at", "t"]},
        {"H&M", ["h", "m"]},
        {"google.com/ads#1", ["google", "com", "ads", "1"]},
        {"a_b-c+d@e", ["a", "b", "c", "d", "e"]},
        {"google\u{D7}ads", ["google", "ads"]},
        {"google\u{2014}ads", ["google", "ads"]},
        {"google\u{2022}ads", ["google", "ads"]},
        {"google\u{1F600}ads", ["google", "ads"]}
      ])
    end

    test "only U+0027 and U+2019 are joined as apostrophes" do
      assert_tokens([
        {"McDonald's", ["mcdonalds"]},
        {"McDonald\u{2019}s", ["mcdonalds"]},
        {"McDonald\u{2018}s", ["mcdonald", "s"]},
        {"McDonald`s", ["mcdonald", "s"]},
        {"McDonald\u{2BC}s", ["mcdonald", "s"]},
        {"McDonald\u{2032}s", ["mcdonald", "s"]}
      ])
    end
  end

  describe "tokens/1 Unicode" do
    test "accents are removed, composed or decomposed" do
      assert_tokens([
        {"Caf\u{E9} Cr\u{E8}me", ["cafe", "creme"]},
        {"Cafe\u{301}", ["cafe"]},
        {"G\u{D6}\u{D6}GLE", ["google"]}
      ])
    end

    test "full-width forms are folded by NFKD" do
      assert_tokens([
        {"\u{FF27}\u{FF2F}\u{FF2F}\u{FF27}\u{FF2C}\u{FF25}\u{FF11}\u{FF12}\u{FF13}",
         ["google", "123"]}
      ])
    end

    test "zero-width and format characters are removed without splitting the token" do
      assert_tokens([
        {"Goo\u{200B}gle", ["google"]},
        {"Goo\u{200D}gle", ["google"]},
        {"Goo\u{AD}gle", ["google"]},
        {"\u{FEFF}google", ["google"]},
        {"goo\u{2060}gle", ["google"]}
      ])
    end

    test "control characters and Unicode spaces are separators" do
      assert_tokens([
        {"google\u{0}ads", ["google", "ads"]},
        {"google\u{7F}ads", ["google", "ads"]},
        {"google\u{85}ads", ["google", "ads"]},
        {"google\u{A0}ads", ["google", "ads"]},
        {"google\u{2003}ads", ["google", "ads"]},
        {"google\u{3000}ads", ["google", "ads"]},
        {"google\u{2028}ads", ["google", "ads"]},
        {"google\tads\r\n", ["google", "ads"]}
      ])
    end

    test "non-Latin scripts are preserved as content" do
      assert_tokens([
        {"Яндекс Такси", ["яндекс", "такси"]},
        {"東京 駅", ["東京", "駅"]},
        {"جوجل", ["جوجل"]}
      ])
    end

    test "default casing: no Turkic mapping" do
      assert_tokens([
        {"TITLE", ["title"]},
        {"\u{130}STANBUL", ["istanbul"]}
      ])
    end

    test "homoglyphs are not mapped" do
      # Cyrillic small o (U+043E) instead of Latin o
      assert {:ok, [token]} = Normalizer.tokens("G\u{43E}\u{43E}gle")
      refute token == "google"
    end
  end

  describe "tokens/1 errors" do
    test "non-binary input" do
      for term <- [nil, 1, :a, [], ["a"], %{}, {:a}, <<1::3>>] do
        assert Normalizer.tokens(term) == {:error, :not_binary}
      end
    end

    test "invalid UTF-8" do
      for input <- [<<0xFF>>, <<0xC3, 0x28>>, "google" <> <<0xFF>>] do
        assert Normalizer.tokens(input) == {:error, :invalid_utf8}
      end
    end

    test "blank input: empty, whitespace, controls, zero-width, marks only" do
      blanks = [
        "",
        " ",
        "   ",
        "\t\n",
        "\u{A0}\u{2003}\u{3000}",
        "\u{200B}",
        "\u{200B}\u{200D}\u{FEFF}",
        "\u{0}\u{1}\u{1F}\u{7F}",
        "\u{301}"
      ]

      for input <- blanks do
        assert Normalizer.tokens(input) == {:error, :blank},
               "expected #{inspect(input)} to be blank"
      end
    end

    test "content without tokens is not blank" do
      for input <- ["***", "'", "\u{2019}", "\u{1F600}", "-"] do
        assert Normalizer.tokens(input) == {:ok, []},
               "expected #{inspect(input)} to be non-blank with no tokens"
      end
    end

    test "size limit is in bytes and checked before content" do
      assert Normalizer.max_input_bytes() == 1024

      assert {:ok, [_token]} = Normalizer.tokens(String.duplicate("a", 1024))
      assert Normalizer.tokens(String.duplicate("a", 1025)) == {:error, :too_large}

      assert {:ok, [_token]} = Normalizer.tokens(String.duplicate("\u{E9}", 512))
      assert Normalizer.tokens(String.duplicate("\u{E9}", 513)) == {:error, :too_large}

      assert Normalizer.tokens(String.duplicate(" ", 2_000)) == {:error, :too_large}
      assert Normalizer.tokens(String.duplicate(<<0xFF>>, 2_000)) == {:error, :too_large}
    end

    test "many tokens within the limit" do
      input = String.duplicate("a ", 512)

      assert byte_size(input) == 1024
      assert {:ok, tokens} = Normalizer.tokens(input)
      assert length(tokens) == 512
    end
  end

  describe "tokens/1 properties on examples" do
    @inputs [
              "DL * GOOGLE A0000021232",
              "Uber UBER * PENDING",
              "C6BANK",
              "McDonald\u{2019}s",
              "Caf\u{E9} Cr\u{E8}me",
              "\u{FF27}\u{FF2F}\u{FF2F}\u{FF27}\u{FF2C}\u{FF25}\u{FF11}\u{FF12}\u{FF13}",
              "Goo\u{200B}gle",
              "\u{130}STANBUL",
              "Яндекс Такси",
              "東京 駅",
              "google.com/ads#1"
            ] ++ Enum.map(Corpus.resolving(), &elem(&1, 0))

    test "is deterministic" do
      for input <- @inputs do
        assert Normalizer.tokens(input) == Normalizer.tokens(input)
      end
    end

    test "is idempotent: normalizing the joined tokens gives the same tokens" do
      for input <- @inputs do
        {:ok, tokens} = Normalizer.tokens(input)

        assert Normalizer.tokens(Enum.join(tokens, " ")) == {:ok, tokens},
               "not idempotent for #{inspect(input)}"
      end
    end

    test "is invariant to letter case for ASCII input" do
      for input <- @inputs, ascii?(input) do
        assert Normalizer.tokens(String.upcase(input)) ==
                 Normalizer.tokens(String.downcase(input)),
               "case changed the result for #{inspect(input)}"
      end
    end

    test "tokens are never empty strings" do
      for input <- @inputs do
        {:ok, tokens} = Normalizer.tokens(input)
        assert Enum.all?(tokens, &(&1 != ""))
      end
    end
  end

  defp ascii?(input), do: input |> :binary.bin_to_list() |> Enum.all?(&(&1 < 128))
end
