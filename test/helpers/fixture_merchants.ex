defmodule MerchantIcons.Test.Helpers.FixtureMerchants do
  @moduledoc false

  # Artificial, synthetic datasets used to exercise behaviour that the production dataset does
  # not contain: shared aliases, priority ties and a merchant with only a :whole alias. Nothing
  # here is real merchant data.

  alias MerchantIcons.Matching.Index

  @doc """
  Artificial merchants:

    * `acme_pay` and `acme_foods` share the alias `acme` (ambiguous on its own);
      `acme_foods` also has the longer alias `acme foods`.
    * `orbit_whole` and `orbit_leading` share the alias `orbit` with different kinds.
    * `solo` only has a `:whole` alias.
  """
  def definitions do
    [
      %{id: "acme_pay", name: "Acme Pay", icon: "acme_pay", aliases: [{"acme", :leading}]},
      %{
        id: "acme_foods",
        name: "Acme Foods",
        aliases: [{"acme", :leading}, {"acme foods", :leading}]
      },
      %{id: "orbit_whole", name: "Orbit", aliases: [{"orbit", :whole}]},
      %{id: "orbit_leading", name: "Orbit Labs", aliases: [{"orbit", :leading}]},
      %{id: "solo", name: "Solo", aliases: [{"solo", :whole}]}
    ]
  end

  @doc "Index over the artificial merchants. Accepts the same options as `Index.build/2`."
  def index(opts \\ []), do: Index.build(definitions(), opts)
end
