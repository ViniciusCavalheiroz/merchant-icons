defmodule MerchantIconsTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Error
  alias MerchantIcons.Merchant
  alias MerchantIcons.Test.Helpers.Corpus

  doctest MerchantIcons

  # Invisible and ambiguous characters are always written as \u{...} escapes in this file.

  @codes [:invalid_input, :input_too_large, :ambiguous_merchant]

  defp assert_contract(result) do
    case result do
      {:ok, %Merchant{}} ->
        :ok

      {:ok, :unknown} ->
        :ok

      {:error, code, message} when code in @codes and is_binary(message) ->
        assert message != ""
    end
  end

  describe "resolve/1 success" do
    test "returns the merchant from the dataset" do
      assert {:ok, %Merchant{id: "google", name: "Google"}} =
               MerchantIcons.resolve("Google ADS2397919998")

      assert {:ok, %Merchant{id: "adobe", name: "Adobe"}} = MerchantIcons.resolve("ADOBE")
    end

    test "the icon is validated SVG markup or nil, never a slug" do
      for {description, _id} <- Corpus.resolving() do
        {:ok, %Merchant{icon: icon}} = MerchantIcons.resolve(description)

        assert is_nil(icon) or MerchantIcons.Icons.validate(icon) == {:ok, icon}
      end
    end

    test "resolves every description of the synthetic corpus" do
      for {description, id} <- Corpus.resolving() do
        assert {:ok, %Merchant{id: ^id}} = MerchantIcons.resolve(description),
               "expected #{inspect(description)} to resolve to #{id}"
      end
    end

    test "Uber UBER * PENDING resolves through the uber alias" do
      assert {:ok, %Merchant{id: "uber"}} = MerchantIcons.resolve("Uber UBER * PENDING")
    end

    test "is insensitive to case, accents, full-width forms and zero-width characters" do
      inputs = [
        "GOOGLE",
        "google",
        "GoOgLe",
        "G\u{D6}\u{D6}GLE ADS",
        "\u{FF27}\u{FF2F}\u{FF2F}\u{FF27}\u{FF2C}\u{FF25}",
        "Goo\u{200B}gle",
        "google\u{A0}ads",
        "google\tads\n123"
      ]

      for input <- inputs do
        assert {:ok, %Merchant{id: "google"}} = MerchantIcons.resolve(input),
               "expected #{inspect(input)} to resolve"
      end
    end

    test "apostrophes are joined, other quote-like characters separate" do
      assert {:ok, %Merchant{id: "adobe"}} = MerchantIcons.resolve("ADO'BE")
      assert {:ok, %Merchant{id: "adobe"}} = MerchantIcons.resolve("ADO\u{2019}BE")
      assert {:ok, :unknown} = MerchantIcons.resolve("ADO\u{2018}BE")
    end

    test "is deterministic" do
      for {description, _id} <- Corpus.resolving() do
        assert MerchantIcons.resolve(description) == MerchantIcons.resolve(description)
      end
    end
  end

  describe "resolve/1 unknown merchant" do
    test "valid descriptions without a match" do
      assert {:ok, :unknown} = MerchantIcons.resolve("PADARIA DO ZE 0042")
    end

    test "false-positive guards and documented limitations stay unknown" do
      for description <- Corpus.unknown() do
        assert {:ok, :unknown} = MerchantIcons.resolve(description),
               "expected #{inspect(description)} to be unknown"
      end
    end

    test "descriptions with content but no tokens are unknown, not invalid" do
      for input <- ["***", "0042", "'", "\u{2019}", "\u{1F600}"] do
        assert MerchantIcons.resolve(input) == {:ok, :unknown},
               "expected #{inspect(input)} to be unknown"
      end
    end

    test "leading tokens that are not approved processor prefixes are not skipped" do
      for description <- ["XY * GOOGLE A0000021232", "PAYPAL * GITHUB INC"] do
        assert {:ok, :unknown} = MerchantIcons.resolve(description)
      end
    end

    test "homoglyphs are not mapped" do
      # Cyrillic small o (U+043E) instead of Latin o
      assert {:ok, :unknown} = MerchantIcons.resolve("G\u{43E}\u{43E}gle")
    end

    test "non-Latin descriptions are preserved as content, not erased" do
      for input <- ["Яндекс Такси", "東京 駅", "جوجل"] do
        assert {:ok, :unknown} = MerchantIcons.resolve(input)
      end
    end
  end

  describe "resolve/1 :invalid_input" do
    test "blank input" do
      blanks = [
        "",
        " ",
        "   ",
        "\t\n",
        "\u{A0}",
        "\u{2003}",
        "\u{3000}",
        "\u{200B}",
        "\u{200B}\u{200D}\u{FEFF}",
        "\u{0}\u{1}\u{1F}",
        "\u{301}"
      ]

      for input <- blanks do
        assert {:error, :invalid_input, message} = MerchantIcons.resolve(input),
               "expected #{inspect(input)} to be invalid"

        assert is_binary(message)
      end
    end

    test "non-binary terms" do
      terms = [
        nil,
        true,
        0,
        1.5,
        :google,
        [],
        ["google"],
        ~c"google",
        %{},
        {:google},
        <<1::3>>,
        fn -> :ok end,
        self(),
        make_ref()
      ]

      for term <- terms do
        assert {:error, :invalid_input, message} = MerchantIcons.resolve(term)
        assert is_binary(message)
      end
    end

    test "invalid UTF-8" do
      for input <- [<<0xFF>>, <<0xC3, 0x28>>, "google" <> <<0xFF>>, <<0xED, 0xA0, 0x80>>] do
        assert {:error, :invalid_input, _} = MerchantIcons.resolve(input)
      end
    end
  end

  describe "resolve/1 :input_too_large" do
    test "accepts exactly the limit and rejects one byte more" do
      assert {:ok, :unknown} = MerchantIcons.resolve(String.duplicate("a", 1024))
      assert {:error, :input_too_large, _} = MerchantIcons.resolve(String.duplicate("a", 1025))
    end

    test "the limit is in bytes, not characters" do
      assert {:ok, :unknown} = MerchantIcons.resolve(String.duplicate("\u{E9}", 512))

      assert {:error, :input_too_large, _} =
               MerchantIcons.resolve(String.duplicate("\u{E9}", 513))
    end

    test "huge input is rejected without being truncated" do
      assert {:error, :input_too_large, _} = MerchantIcons.resolve(:binary.copy("a", 10_000_000))

      assert {:error, :input_too_large, _} =
               MerchantIcons.resolve("google " <> :binary.copy("a", 5_000))
    end

    test "size is checked before content" do
      assert {:error, :input_too_large, _} = MerchantIcons.resolve(String.duplicate(" ", 2_000))

      assert {:error, :input_too_large, _} =
               MerchantIcons.resolve(String.duplicate(<<0xFF>>, 2_000))
    end
  end

  describe "contract" do
    test "every result is {:ok, %Merchant{}} or a 3-tuple with a documented code" do
      inputs =
        [nil, "", "   ", "***", "google", "x", <<0xFF>>, String.duplicate("a", 5_000), :atom, 1] ++
          Enum.map(Corpus.resolving(), &elem(&1, 0)) ++ Corpus.unknown()

      for input <- inputs, do: assert_contract(MerchantIcons.resolve(input))
    end

    test "never raises for unexpected input" do
      inputs = [nil, 1, :a, [], %{}, {}, <<0xFF, 0xFE>>, "", self(), fn -> :ok end]

      for input <- inputs do
        assert is_tuple(MerchantIcons.resolve(input))
      end
    end

    test "composes with case/2 and pattern matching" do
      result =
        case MerchantIcons.resolve("Uber Trip") do
          {:ok, %Merchant{id: id}} -> {:resolved, id}
          {:ok, :unknown} -> :unknown
          {:error, _code, _message} -> :other
        end

      assert result == {:resolved, "uber"}

      result =
        case MerchantIcons.resolve("nothing here") do
          {:ok, %Merchant{id: id}} -> {:resolved, id}
          {:ok, :unknown} -> :unknown
          {:error, _code, _message} -> :other
        end

      assert result == :unknown
    end
  end

  describe "MerchantIcons.Error.build/1" do
    test "maps each internal reason to its public code" do
      mapping = [
        not_binary: :invalid_input,
        invalid_utf8: :invalid_input,
        blank: :invalid_input,
        too_large: :input_too_large,
        ambiguous: :ambiguous_merchant
      ]

      for {reason, code} <- mapping do
        assert {:error, ^code, message} = Error.build(reason)

        assert message != ""
        assert is_binary(message)
      end
    end

    test "builds the ambiguous public tuple" do
      assert {:error, :ambiguous_merchant, _} = Error.build(:ambiguous)
    end
  end
end
