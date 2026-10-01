# Benchmark baseline

Run with `mix run bench/<script>.exs` (Benchee is a dev-only dependency). The inputs are
synthetic. Numbers come from one machine (OTP 29, Elixir 1.20.2, 10 schedulers) and one run:
use them to compare before and after on the same machine, not as absolute values.

| Script | Measures |
|---|---|
| `bench/resolve.exs` | `resolve/1` by input kind and size, and 200,000 resolves spread over 1, 10, 100 and 1,000 processes |
| `bench/icon_data_uri.exs` | `icon_data_uri/1` per bundled icon size |
| `bench/component.exs` | `merchant_icon/1` rendered to a string for 10 to 10,000 rows, with `name=`, `merchant=` and `fallback`, plus the HTML size |

## `resolve/1` (unchanged by the data URI change)

| Input | Average |
|---|---|
| known, with icon | ~5 µs |
| known, no icon | ~4.7 µs |
| known, alias only (`ADOBE`) | ~3.4 µs |
| unknown, short | ~4.8 µs |
| invalid (blank) | ~1.3 µs |
| known or unknown, ~1000 bytes | ~100-110 µs |

| 200,000 resolves over | Time |
|---|---|
| 1 process | ~1100 ms |
| 10 processes | ~230 ms |
| 100 processes | ~220 ms |
| 1,000 processes | ~250 ms |

## `icon_data_uri/1`: before and after precomputing the data URIs

| Icon | Before | After |
|---|---|---|
| Google (8.5 KB svg) | 8.7 µs | 0.19 µs |
| OpenAI (2.4 KB svg) | 2.6 µs | 0.08 µs |
| Spotify (1.0 KB svg) | 1.2 µs | 0.06 µs |
| Adobe (0.5 KB svg) | 0.65 µs | 0.02 µs |
| merchant without icon | 4.5 ns | 4.7 ns |

## `merchant_icon/1`, 1,000 rows (rows are Google, Adobe, unknown, Uber in turn)

| Variant | Before | After |
|---|---|---|
| `name=` | 13.5 ms | 9.4 ms |
| `merchant=` | 8.4 ms | 4.8 ms |
| `name=` + `fallback` | 25.6 ms | 19.9 ms |

`merchant=` skips the resolve. In the "before" run it already did, so the gap between `name=` and
`merchant=` is the cost of resolving 1,000 descriptions inside the render.

`fallback` is validated on every render and is not precomputed. That is a known cost, not
changed here.

## HTML size (`name=`, same rows)

| Rows | HTML | gzip |
|---|---|---|
| 10 | 27 KB | 5 KB |
| 100 | 326 KB | 8 KB |
| 1,000 | 3.3 MB | 28 KB |
| 10,000 | 32.6 MB | 230 KB |

The size is dominated by the repeated `data:` URI of the icons that have one. It does not change
with precomputation. Paginate or use LiveView streams for long lists.
