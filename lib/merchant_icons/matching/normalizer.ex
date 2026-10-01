defmodule MerchantIcons.Matching.Normalizer do
  @moduledoc false

  @max_input_bytes 1024

  @type reason :: :not_binary | :too_large | :invalid_utf8 | :blank

  @doc "Maximum accepted size of a description, in bytes (provisional)."
  @spec max_input_bytes() :: pos_integer()
  def max_input_bytes, do: @max_input_bytes

  @doc """
  Returns the tokens of a description, or an internal error reason.

  The result is `{:ok, []}` for a non-blank description that has no tokens (for example
  `"***"`).
  """
  @spec tokens(term()) :: {:ok, [String.t()]} | {:error, reason()}
  def tokens(input) do
    input
    |> validate()
    |> canonicalize()
    |> reject_blank()
    |> tokenize()
  end

  # The size check is O(1) and runs before anything scans the content.
  defp validate(input) when not is_binary(input), do: {:error, :not_binary}
  defp validate(input) when byte_size(input) > @max_input_bytes, do: {:error, :too_large}

  defp validate(input) do
    case String.valid?(input) do
      true ->
        {:ok, input}

      false ->
        {:error, :invalid_utf8}
    end
  end

  defp canonicalize({:error, _reason} = error), do: error

  defp canonicalize({:ok, input}) do
    text =
      input
      |> :unicode.characters_to_nfkd_binary()
      |> String.downcase(:default)
      |> remove_ignorable()

    {:ok, text}
  end

  # Removed without splitting the token: format characters (zero-width, bidi, BOM, tags),
  # general combining diacritics and variation selectors. Script-specific marks stay.
  defp remove_ignorable(text) do
    String.replace(
      text,
      ~r/[\p{Cf}\x{0300}-\x{036F}\x{1AB0}-\x{1AFF}\x{1DC0}-\x{1DFF}\x{20D0}-\x{20FF}\x{FE00}-\x{FE0F}\x{FE20}-\x{FE2F}\x{E0100}-\x{E01EF}]/u,
      ""
    )
  end

  defp reject_blank({:error, _reason} = error), do: error

  defp reject_blank({:ok, text}) do
    case String.match?(text, ~r/\A[\s\p{Z}\p{Cc}]*\z/u) do
      true ->
        {:error, :blank}

      false ->
        {:ok, text}
    end
  end

  defp tokenize({:error, _reason} = error), do: error

  defp tokenize({:ok, text}) do
    tokens =
      text
      |> join_apostrophes()
      |> scan_tokens()

    {:ok, tokens}
  end

  # Only U+0027 and U+2019 join ("d'agua" -> "dagua"). Other apostrophe-like characters, such
  # as U+02BC, separate.
  defp join_apostrophes(text), do: String.replace(text, ["'", "\u{2019}"], "")

  # A token is a run of ASCII digits or a run of content: anything that is not a digit,
  # whitespace, control, punctuation, symbol or U+02B9..U+02BF. The alternatives are disjoint,
  # so a letter/digit boundary splits the token. Non-ASCII digits count as content.
  defp scan_tokens(text) do
    ~r/[0-9]+|[^0-9\s\p{Z}\p{Cc}\p{P}\p{S}\x{02B9}-\x{02BF}]+/u
    |> Regex.scan(text)
    |> List.flatten()
  end
end
