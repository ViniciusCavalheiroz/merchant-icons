defmodule MerchantIcons.SecurityTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MerchantIcons.Error
  alias MerchantIcons.Merchant

  # Invisible and ambiguous characters are always written as \u{...} escapes in this file.

  # A unique marker that stands for sensitive transaction data. It must never appear in any
  # result, message or log line.
  @canary "CANARY-4821"

  @lib_dir Path.expand("../../lib", __DIR__)

  defp inputs_with_canary do
    [
      @canary,
      "google " <> @canary,
      "adobe " <> @canary,
      "uber " <> @canary <> " 99",
      @canary <> <<0xFF>>,
      @canary <> String.duplicate("x", 2_000),
      " \u{200B}" <> @canary <> "\u{200B} ",
      {:canary, @canary},
      [@canary],
      %{canary: @canary},
      String.to_charlist(@canary)
    ]
  end

  describe "no transaction data in results" do
    test "results and messages never contain the input" do
      for input <- inputs_with_canary() do
        result = MerchantIcons.resolve(input)

        refute inspect(result) =~ @canary, "result leaked input: #{inspect(result)}"

        case result do
          {:error, _code, message} -> refute message =~ @canary
          {:ok, %Merchant{}} -> :ok
          {:ok, :unknown} -> :ok
        end
      end
    end

    test "a successful result only contains dataset values, never parts of the input" do
      assert {:ok, %Merchant{id: "google", name: "Google"}} =
               MerchantIcons.resolve("google " <> @canary)

      assert {:ok, merchant} = MerchantIcons.resolve("uber " <> @canary <> " 99")
      refute inspect(merchant) =~ @canary
    end

    test "error messages are static" do
      for reason <- [:not_binary, :invalid_utf8, :blank, :too_large, :ambiguous] do
        assert Error.build(reason) == Error.build(reason)
        {:error, _code, message} = Error.build(reason)
        refute message =~ @canary
      end
    end

    test "the size message states the limit, not the size of the input" do
      {:error, :input_too_large, message} = MerchantIcons.resolve(String.duplicate("a", 123_456))

      assert message =~ "1024"
      refute message =~ "123456"
    end
  end

  describe "no logging" do
    test "resolving emits no log output" do
      output =
        capture_log(fn ->
          for input <- inputs_with_canary(), do: MerchantIcons.resolve(input)
          MerchantIcons.resolve("DL * GOOGLE A0000021232")
          MerchantIcons.resolve("")
          MerchantIcons.resolve(nil)
        end)

      assert output == ""
    end
  end

  describe "hostile input" do
    test "never raises" do
      hostile = [
        :binary.copy("a", 10_000_000),
        :binary.copy(<<0>>, 5_000),
        String.duplicate("\u{301}", 500),
        String.duplicate("\u{200B}", 300),
        String.duplicate("\u{301}", 600),
        String.duplicate("\u{200B}", 600),
        String.duplicate("*", 1_024),
        String.duplicate("a1", 512),
        String.duplicate("\u{1F600}", 256),
        <<0xFF, 0xFE, 0xFD>>,
        <<0xC0, 0x80>>,
        <<0xED, 0xA0, 0x80>>,
        <<0xF4, 0x90, 0x80, 0x80>>
      ]

      for input <- hostile do
        assert is_tuple(MerchantIcons.resolve(input))
      end
    end

    test "pathological but valid inputs within the limit are handled" do
      for input <- [
            String.duplicate("a ", 512),
            String.duplicate("1a", 512),
            String.duplicate("a-", 512),
            String.duplicate("google ", 146)
          ] do
        assert byte_size(input) <= 1024
        assert is_tuple(MerchantIcons.resolve(input))
      end
    end

    test "expanding Unicode within the limit stays bounded and valid" do
      # U+FDFA expands to 18 codepoints under NFKD.
      input = String.duplicate("\u{FDFA}", 340)

      assert byte_size(input) <= 1024
      assert is_tuple(MerchantIcons.resolve(input))
    end
  end

  # Regular expressions are allowed only in the normalizer: its patterns are fixed literals made
  # of character classes (linear matching) applied to input limited to 1024 bytes.
  @regex_patterns ["Regex.", "~r"]
  @regex_file "merchant_icons/matching/normalizer.ex"

  defp regex_allowed?(file, pattern) do
    pattern in @regex_patterns and Path.relative_to(file, @lib_dir) == @regex_file
  end

  describe "library source hygiene" do
    # Static checks of the rules in CLAUDE.md. They are deliberately crude: the goal is to
    # force a conscious decision before any of these constructs enters lib/.
    @forbidden [
      {"Code.eval", "dynamic code execution"},
      {"String.to_atom", "atoms created from input"},
      {"binary_to_term", "unsafe deserialization"},
      {"Regex.", "regular expressions"},
      {"~r", "regular expression sigil"},
      {"Logger", "logging"},
      {" rescue", "generic rescue"},
      {"catch ", "generic catch"},
      {":ets", "ETS"},
      {"persistent_term", "persistent_term"},
      {":httpc", "network access"},
      {":gen_tcp", "network access"},
      {"GenServer", "background processes"},
      {"Application.get_env", "global configuration"},
      {"app_dir", "runtime path lookup"},
      {"priv_dir", "runtime path lookup"}
    ]

    test "lib/ does not contain forbidden constructs" do
      files = Path.wildcard(Path.join(@lib_dir, "**/*.ex"))

      assert files != []

      for file <- files, {pattern, reason} <- @forbidden, not regex_allowed?(file, pattern) do
        refute File.read!(file) =~ pattern,
               "#{Path.relative_to(file, @lib_dir)} contains #{inspect(pattern)} (#{reason})"
      end
    end

    test "lib/ contains no invisible or bidirectional control characters" do
      # Trojan-source style characters must never be written literally into the library.
      suspicious =
        [0x200B..0x200F, 0x202A..0x202E, 0x2060..0x206F, [0xFEFF, 0xAD, 0x2028, 0x2029]]
        |> Enum.flat_map(&Enum.to_list/1)

      for file <- Path.wildcard(Path.join(@lib_dir, "**/*.ex")),
          codepoint <- suspicious do
        refute File.read!(file) =~ <<codepoint::utf8>>,
               "#{Path.relative_to(file, @lib_dir)} contains U+#{Integer.to_string(codepoint, 16)}"
      end
    end
  end
end
