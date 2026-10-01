# mix run bench/resolve.exs
#
# Baseline for MerchantIcons.resolve/1. The descriptions are synthetic.

long_unknown = String.duplicate("PADARIA DO ZE 0042 ", 55) |> binary_part(0, 1000)
long_known = "GOOGLE " <> String.duplicate("ADS 123 ", 120)

inputs = %{
  "known, with icon" => "DL * GOOGLE A0000000123",
  "known, no icon" => "Uber UBER * PENDING",
  "known, alias only" => "ADOBE",
  "unknown, short" => "PADARIA DO ZE 0042",
  "unknown, ~1000 bytes" => long_unknown,
  "known, ~1000 bytes" => long_known,
  "invalid (blank)" => "   "
}

Benchee.run(
  %{"resolve/1" => fn description -> MerchantIcons.resolve(description) end},
  inputs: inputs,
  warmup: 1,
  time: 3,
  memory_time: 1,
  print: [fast_warning: false]
)

# Concurrency: the same work spread over N processes. Compare ips across rows.
description = "DL * GOOGLE A0000000123"
total = 200_000

concurrent = fn processes ->
  fn ->
    per_process = div(total, processes)

    1..processes
    |> Enum.map(fn _ ->
      Task.async(fn -> for _ <- 1..per_process, do: MerchantIcons.resolve(description) end)
    end)
    |> Task.await_many(120_000)
  end
end

Benchee.run(
  Map.new([1, 10, 100, 1_000], fn n ->
    {"#{total} resolves over #{n} process(es)", concurrent.(n)}
  end),
  warmup: 1,
  time: 5,
  print: [fast_warning: false]
)
