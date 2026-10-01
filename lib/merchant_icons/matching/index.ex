defmodule MerchantIcons.Matching.Index do
  @moduledoc false

  # Lookup structure built from a dataset. Aliases go through the same normalization as
  # transaction descriptions and are grouped by their first token.
  #
  # Invalid data raises `ArgumentError` (at compile time for the production dataset). Messages
  # only mention dataset values, never transaction data.

  alias MerchantIcons.Matching.Noise
  alias MerchantIcons.Matching.Normalizer
  alias MerchantIcons.Merchant

  defstruct entries: %{}, prefixes: %{}

  @type kind :: :whole | :leading

  @type definition :: %{
          required(:id) => String.t(),
          required(:name) => String.t(),
          optional(:icon) => String.t() | nil,
          required(:aliases) => [{String.t(), kind()}]
        }

  @type entry :: %{
          tokens: [String.t(), ...],
          length: pos_integer(),
          kind: kind(),
          merchant: Merchant.t()
        }

  @type t :: %__MODULE__{
          entries: %{optional(String.t()) => [entry()]},
          prefixes: %{optional(String.t()) => true}
        }

  @doc """
  Builds an index from merchant definitions.

  Options:

    * `:prefixes` - processor prefix tokens (default: `MerchantIcons.Matching.Noise.prefixes/0`)

  The same alias may belong to several merchants on purpose (the matcher reports it as
  ambiguous). The same alias twice in one merchant is an error.
  """
  @spec build([definition()], keyword()) :: t()
  def build(definitions, opts \\ []) when is_list(definitions) do
    %{definitions: definitions, prefixes: Keyword.get(opts, :prefixes, Noise.prefixes())}
    |> build_prefixes()
    |> build_merchants()
    |> build_entries()
    |> to_index()
  end

  defp build_prefixes(%{prefixes: values} = params) do
    %{params | prefixes: Map.new(values, &prefix_entry!/1)}
  end

  defp prefix_entry!(value) do
    case Normalizer.tokens(value) do
      {:ok, [token]} ->
        {token, true}

      _other ->
        raise ArgumentError,
              "prefix entries must normalize to exactly one token, got: #{inspect(value)}"
    end
  end

  # build_merchants

  defp build_merchants(%{definitions: definitions} = params) do
    merchants = Enum.map(definitions, &build_merchant!/1)

    merchants
    |> Enum.map(& &1.id)
    |> ensure_unique!("merchant ids must be unique")

    Map.put(params, :merchants, merchants)
  end

  defp build_merchant!(%{id: id, name: name} = definition)
       when is_binary(id) and is_binary(name) do
    icon = Map.get(definition, :icon)

    validate_id!(id)
    validate_name!(id, name)
    validate_icon!(id, icon)

    %Merchant{id: id, name: name, icon: icon}
  end

  defp build_merchant!(_definition) do
    raise ArgumentError, "merchant definitions must be maps with binary :id and :name keys"
  end

  defp validate_id!(id) do
    ensure!(snake_case_id?(id), "merchant id must be snake_case ASCII, got: #{inspect(id)}")
  end

  defp validate_name!(id, name) do
    ensure!(String.trim(name) != "", "merchant #{inspect(id)} must have a non-blank name")
  end

  defp validate_icon!(_id, nil), do: :ok
  defp validate_icon!(_id, icon) when is_binary(icon), do: :ok

  defp validate_icon!(id, _icon) do
    raise ArgumentError, "merchant #{inspect(id)} has an invalid icon"
  end

  # build_entries

  defp build_entries(
         %{definitions: definitions, merchants: merchants, prefixes: prefixes} = params
       ) do
    entries =
      definitions
      |> Enum.zip(merchants)
      |> Enum.flat_map(&build_merchant_entries!(&1, prefixes))
      |> Enum.group_by(&first_token/1)

    Map.put(params, :entries, entries)
  end

  defp build_merchant_entries!({%{aliases: [_ | _] = aliases}, merchant}, prefixes) do
    entries = Enum.map(aliases, &build_entry!(&1, merchant, prefixes))

    entries
    |> Enum.map(& &1.tokens)
    |> ensure_unique!("merchant #{inspect(merchant.id)} defines the same alias more than once")

    entries
  end

  defp build_merchant_entries!({_definition, merchant}, _prefixes) do
    raise ArgumentError,
          "merchant #{inspect(merchant.id)} must define a non-empty list of aliases"
  end

  defp build_entry!({text, kind}, merchant, prefixes)
       when is_binary(text) and kind in [:whole, :leading] do
    tokens = alias_tokens!(text, merchant)

    validate_not_prefix!(tokens, text, merchant, prefixes)
    validate_not_digits_only!(tokens, text, merchant)

    %{tokens: tokens, length: length(tokens), kind: kind, merchant: merchant}
  end

  defp build_entry!(_alias, merchant, _prefixes) do
    raise ArgumentError,
          "merchant #{inspect(merchant.id)} has an alias that is not a {binary, :whole | :leading} tuple"
  end

  defp alias_tokens!(text, merchant) do
    case Normalizer.tokens(text) do
      {:ok, [_ | _] = tokens} ->
        tokens

      {:ok, []} ->
        raise ArgumentError, "#{describe(text, merchant)} has no tokens after normalization"

      {:error, reason} ->
        raise ArgumentError, "#{describe(text, merchant)} is invalid (#{reason})"
    end
  end

  defp validate_not_prefix!([first | _rest], text, merchant, prefixes) do
    ensure!(
      not Map.has_key?(prefixes, first),
      "#{describe(text, merchant)} starts with a processor prefix"
    )
  end

  defp validate_not_digits_only!(tokens, text, merchant) do
    ensure!(
      not Enum.all?(tokens, &Noise.digits_only?/1),
      "#{describe(text, merchant)} consists only of digits"
    )
  end

  defp first_token(%{tokens: [first | _rest]}), do: first

  defp describe(text, merchant), do: "alias #{inspect(text)} of merchant #{inspect(merchant.id)}"

  # to_index

  defp to_index(%{entries: entries, prefixes: prefixes}) do
    %__MODULE__{entries: entries, prefixes: prefixes}
  end

  # helpers

  # snake_case ASCII: segments of [a-z0-9] separated by single underscores.
  defp snake_case_id?(value) do
    value
    |> :binary.split("_", [:global])
    |> Enum.all?(&snake_case_segment?/1)
  end

  defp snake_case_segment?(""), do: false

  defp snake_case_segment?(segment) do
    segment
    |> :binary.bin_to_list()
    |> Enum.all?(&(&1 in ?a..?z or &1 in ?0..?9))
  end

  defp ensure_unique!(values, message) do
    ensure!(length(Enum.uniq(values)) == length(values), message)
  end

  defp ensure!(true, _message), do: :ok
  defp ensure!(false, message), do: raise(ArgumentError, message)
end
