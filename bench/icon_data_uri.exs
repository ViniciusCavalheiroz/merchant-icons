# mix run bench/icon_data_uri.exs
#
# Baseline for MerchantIcons.icon_data_uri/1, one merchant per bundled icon size.

merchants =
  for description <- ["Google", "OpenAI", "Spotify", "ADOBE"], into: %{} do
    {:ok, merchant} = MerchantIcons.resolve(description)
    {"#{merchant.name} (#{byte_size(merchant.icon)} B svg)", merchant}
  end

no_icon = %MerchantIcons.Merchant{id: "shop", name: "Shop", icon: nil}

Benchee.run(
  %{"icon_data_uri/1" => fn merchant -> MerchantIcons.icon_data_uri(merchant) end},
  inputs: Map.put(merchants, "merchant without icon", no_icon),
  warmup: 1,
  time: 3,
  memory_time: 1,
  print: [fast_warning: false]
)
