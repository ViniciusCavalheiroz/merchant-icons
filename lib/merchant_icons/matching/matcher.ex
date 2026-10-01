defmodule MerchantIcons.Matching.Matcher do
  @moduledoc false

  # Deterministic matching of tokens against an `MerchantIcons.Matching.Index`:
  #
  #     tokens |> skip_prefixes() |> find_candidates() |> select_by_priority()
  #
  # Matching compares whole tokens. There is no substring or character-prefix matching.
  #
  # Noise is interpreted here, not before, because a token's meaning depends on the match: a
  # digits-only token is noise after a `:whole` alias but content inside an alias such as
  # `C6 Bank`.

  alias MerchantIcons.Matching.Index
  alias MerchantIcons.Matching.Noise

  def match(tokens, %Index{} = index) when is_list(tokens) do
    tokens
    |> skip_prefixes(index)
    |> find_candidates(index)
    |> select_by_priority()
  end

  defp skip_prefixes([], _index), do: []

  defp skip_prefixes([token | rest] = tokens, index) do
    case prefix?(token, index) do
      true -> skip_prefixes(rest, index)
      false -> tokens
    end
  end

  defp prefix?(token, %Index{prefixes: prefixes}), do: Map.has_key?(prefixes, token)

  defp find_candidates([], _index), do: []

  defp find_candidates([first | _rest] = tokens, %Index{entries: entries}) do
    entries
    |> Map.get(first, [])
    |> Enum.filter(&admissible?(&1, tokens))
  end

  defp admissible?(%{tokens: alias_tokens, kind: kind}, tokens) do
    case strip_alias(tokens, alias_tokens) do
      {:ok, remainder} -> accepts_remainder?(kind, remainder)
      :nomatch -> false
    end
  end

  defp strip_alias(remainder, []), do: {:ok, remainder}
  defp strip_alias([token | tokens], [token | alias_rest]), do: strip_alias(tokens, alias_rest)
  defp strip_alias(_tokens, _alias_tokens), do: :nomatch

  defp accepts_remainder?(:leading, _remainder), do: true
  defp accepts_remainder?(:whole, remainder), do: Enum.all?(remainder, &Noise.digits_only?/1)

  defp select_by_priority([]), do: {:error, :unknown}

  defp select_by_priority(candidates) do
    candidates
    |> top_priority_merchants()
    |> single_merchant()
  end

  defp top_priority_merchants(candidates) do
    top = candidates |> Enum.map(&priority/1) |> Enum.max()

    candidates
    |> Enum.filter(&(priority(&1) == top))
    |> Enum.map(& &1.merchant)
    |> Enum.uniq_by(& &1.id)
  end

  defp priority(%{length: length, kind: :whole}), do: {length, 1}
  defp priority(%{length: length, kind: :leading}), do: {length, 0}

  defp single_merchant([merchant]), do: {:ok, merchant}
  defp single_merchant(_several_merchants), do: {:error, :ambiguous}
end
