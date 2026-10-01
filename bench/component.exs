# mix run bench/component.exs
#
# Baseline for MerchantIcons.Components.merchant_icon/1 rendered to a string. Requires
# :phoenix_live_view, which is an optional dependency available in this project's own build.

import Phoenix.Component
import Phoenix.LiveViewTest
import MerchantIcons.Components

descriptions = ["GOOGLE ADS 1", "ADOBE 2", "PADARIA DO ZE 3", "Uber UBER * PENDING"]

rows = fn n -> for i <- 1..n, do: Enum.at(descriptions, rem(i, 4)) end

fallback =
  ~s|<svg viewBox="0 0 1 1" xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>|

by_name = fn names ->
  assigns = %{names: names}
  rendered_to_string(~H"<%= for name <- @names do %><.merchant_icon name={name} /><% end %>")
end

by_merchant = fn merchants ->
  assigns = %{merchants: merchants}

  rendered_to_string(
    ~H"<%= for merchant <- @merchants do %><.merchant_icon merchant={merchant} /><% end %>"
  )
end

with_fallback = fn names ->
  assigns = %{names: names, fallback: fallback}

  rendered_to_string(
    ~H"<%= for name <- @names do %><.merchant_icon name={name} fallback={@fallback} /><% end %>"
  )
end

resolve = fn names ->
  for name <- names do
    case MerchantIcons.resolve(name) do
      {:ok, %MerchantIcons.Merchant{} = merchant} -> merchant
      _other -> %MerchantIcons.Merchant{id: "unknown", name: name, icon: nil}
    end
  end
end

inputs =
  Map.new([10, 100, 1_000, 10_000], fn n ->
    names = rows.(n)
    {"#{n} rows", %{names: names, merchants: resolve.(names)}}
  end)

Benchee.run(
  %{
    "merchant_icon name=" => fn %{names: names} -> by_name.(names) end,
    "merchant_icon merchant=" => fn %{merchants: merchants} -> by_merchant.(merchants) end,
    "merchant_icon name= + fallback" => fn %{names: names} -> with_fallback.(names) end
  },
  inputs: inputs,
  warmup: 1,
  time: 3,
  memory_time: 1,
  print: [fast_warning: false]
)

# Payload size per number of rows (html bytes), independent of timing.
for {label, %{names: names}} <- Enum.sort_by(inputs, fn {_k, v} -> length(v.names) end) do
  html = by_name.(names)

  IO.puts(
    "#{label}: #{byte_size(html)} bytes of html, #{byte_size(:zlib.gzip(html))} bytes gzipped"
  )
end
