# MerchantIcons

[![Hex.pm](https://img.shields.io/hexpm/v/merchant_icons.svg)](https://hex.pm/packages/merchant_icons)
[![Docs](https://img.shields.io/badge/docs-hexdocs-purple.svg)](https://hexdocs.pm/merchant_icons)

> Turn a noisy merchant description into a known merchant and its icon. Offline, stateless and
> safe by design.

```elixir
iex> {:ok, merchant} = MerchantIcons.resolve("DL * GOOGLE A0000033333")
iex> {merchant.id, merchant.name}
{"google", "Google"}
```

## Overview

Bank and card statements describe merchants in messy ways: processor prefixes, codes, numbers,
statuses, random casing and accents.

```text
DL * GOOGLE A0000033333
Google A0000033333
Uber UBER * PENDING
DL * UberRides
ADOBE
```

`MerchantIcons.resolve/1` takes one of these descriptions and:

1. validates and **normalizes** it (Unicode NFKD, accents removed, case folded, zero-width
   characters removed);
2. splits it into tokens and ignores a known processor prefix;
3. **matches** it against a small static dataset of merchants;
4. returns `{:ok, %MerchantIcons.Merchant{}}` with the merchant `id`, `name` and, when available,
   the complete **SVG markup** of its icon, or `{:ok, :unknown}` when the merchant is not in the
   dataset.

What it deliberately is **not**:

* It has no network access. Resolution and icons work offline, and the SVGs are embedded when the
  library compiles.
* It keeps no state: no database, cache, process or file access at runtime.
* It does not deal with amounts, currencies, categories or any other financial data. The
  description is only the input used to find the merchant.
* It never logs, stores or returns the description (see [Security](#security-and-privacy)).

## Installation

Requires Elixir `~> 1.20`. The only dependency is [`:telemetry`](https://hex.pm/packages/telemetry).

Add `merchant_icons` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:merchant_icons, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
case MerchantIcons.resolve("Uber UBER * PENDING") do
  {:ok, :unknown} ->
    # valid description, merchant not in the dataset
    :unknown

  {:ok, %MerchantIcons.Merchant{id: id, name: name, icon: icon}} ->
    {id, name, icon}

  {:error, _code, _message} ->
    # invalid, too large or ambiguous input
    :error
end
```

It composes naturally with pipelines and pattern matching:

```elixir
with_icon =
  for description <- ["ADOBE", "Google A0000033333", "PADARIA DO ZE 0042"],
      {:ok, %MerchantIcons.Merchant{icon: icon} = merchant} when is_binary(icon) <-
        [MerchantIcons.resolve(description)] do
    merchant
  end
```

Examples of what resolves to what:

| Description               | Result                    |
|---------------------------|---------------------------|
| `DL * GOOGLE A0000033333` | `Google`                  |
| `Google A0000033333`    | `Google`                  |
| `Google One`              | `Google One`              |
| `Uber UBER * PENDING`     | `Uber`                    |
| `DL * UberRides`          | `Uber`                    |
| `ADOBE`                   | `Adobe`                   |
| `PADARIA DO ZE 0042`      | `{:ok, :unknown}`         |

## Usage in a Phoenix application

The quickest path is the ready-made component. `import MerchantIcons.Components` and call
`merchant_icon/1` with the raw description. It resolves the merchant, renders the icon and
handles merchants without one — you deal with none of that:

```elixir
import MerchantIcons.Components

~H"""
<.merchant_icon name={@transaction.merchant_name} />
<.merchant_icon name="Some Shop" size={40} class="shadow" />
<.merchant_icon name="Unknown LTDA" fallback={@store_svg} />
"""
```

It renders a self-contained round badge (inline styles, no CSS framework needed; `size`
defaults to 32px, and `class`/other attributes pass through to the outer element). The icon is
rendered as an `<img>` with a `data:` URI rather than inlined — see the note below.

**Fallback order**, when the description has no bundled icon:

1. the merchant's icon, when the description resolves to one;
2. the `fallback` SVG markup you pass (validated the same way bundled icons are; invalid markup
   is ignored);
3. a badge with the first letter of the merchant/description name.

### Optional dependency

`MerchantIcons.Components` needs `Phoenix.Component`, so `:phoenix_live_view` is an **optional**
dependency: projects that use the library only as a resolver never pull Phoenix in. In a Phoenix
app you already have it, and the component is available. If the module does not appear, make sure
`:phoenix_live_view` is compiled before `:merchant_icons` (the usual case in a Phoenix project).

### Rendering the markup yourself

If you render `merchant.icon` directly instead of using the component, note that it is trusted
markup that ships with the library, so it can be rendered unescaped with `Phoenix.HTML.raw/1`.
Never do this with text that came from the description: the description is never part of the
struct.

Some icons carry internal ids (gradients, `clipPath`, filters) referenced with `url(#id)`.
Inlining the same icon more than once on a page — a list, or LiveView's server/client DOM —
makes those ids collide and the references stop painting. Render the icon as an image to isolate
the ids: use the component above, or `MerchantIcons.icon_data_uri/1` as an `<img>` `src`.

## Input and output

### Input

`resolve/1` accepts any term and never raises because of its input. Descriptions are always
treated as untrusted data. A valid description is a non-blank, valid UTF-8 binary of at most
**1024 bytes**. Larger input is rejected, not truncated. The limit is in bytes and is provisional:
raising it later is compatible, lowering it is not.

### Output

`resolve/1` returns one of:

| Result                               | Meaning                                                      |
|--------------------------------------|--------------------------------------------------------------|
| `{:ok, %MerchantIcons.Merchant{}}`   | a merchant was identified                                    |
| `{:ok, :unknown}`                    | valid description, but no merchant in the dataset matches it |
| `{:error, :invalid_input, msg}`      | not a binary, invalid UTF-8, or empty/blank                  |
| `{:error, :input_too_large, msg}`    | larger than 1024 bytes                                       |
| `{:error, :ambiguous_merchant, msg}` | several merchants match and no rule picks one                |

An unknown merchant is **not** an error: it means the dataset does not cover that merchant yet.

Error tuples always have three elements. Branch on the `code`; the `message` is informative
English text and is not part of the contract. No message contains the description or any other
input. The set of codes is open (new codes may appear in minor versions), so keep a clause that
matches any `{:error, _code, _message}`.

### The merchant struct

| Field   | Type                  | Description                                                    |
|---------|-----------------------|----------------------------------------------------------------|
| `:id`   | `String.t()`          | stable `snake_case` identifier, such as `"google"`             |
| `:name` | `String.t()`          | display name, such as `"Google"`                               |
| `:icon` | `String.t() \| nil`   | complete SVG markup of the logo, or `nil` when there is none   |

The struct only contains dataset values, never any part of the description. The icon is left out
of `inspect/1` because of its size. New fields may be added in minor versions, so match on the
keys you need.

## Icons

`merchant.icon` is the SVG itself, not a URL, path or slug:

```elixir
{:ok, merchant} = MerchantIcons.resolve("ADOBE")
"<svg" <> _ = merchant.icon
```

* Icons live in `priv/icons/*.svg` and are embedded in the library at compile time. Getting an
  icon never touches the network or the file system.
* The markup is meant to be inlined in HTML and scaled with CSS (every icon has a `viewBox`).
* Every SVG is validated while the library compiles, and a bad file stops the build. The checks
  are deliberately strict and work on the text of the file (there is no XML parser):
  * rejected: scripts, event handlers (`on*`), `foreignObject`, `<iframe>`, `<object>`,
    `<embed>`, `<!DOCTYPE>`, entities and any `&`, `javascript:` and `data:` URIs, and `@import`;
  * `href`, `src` and `url(...)` may only point to an `#id` inside the same file, so any other
    reference, such as `http:`, `//host` or a relative path, is rejected;
  * the file must start with `<svg` (with a `viewBox`), end with `</svg>`, be a regular file (no
    symlinks) and be at most 100,000 bytes.
* When `icon` is `nil`, the merchant has no icon yet. Treat it like an unknown icon and choose your
  own fallback.

Merchant logos are trademarks of their respective owners.

## Telemetry

`resolve/1` emits one [`:telemetry`](https://hexdocs.pm/telemetry) event when it identifies a
merchant or concludes that it is unknown:

| Event                         | Measurements  | Metadata                                                          |
|-------------------------------|---------------|-------------------------------------------------------------------|
| `[:merchant_icons, :resolve]` | `%{count: 1}` | `%{result: :merchant_resolved}` or `%{result: :merchant_unknown}` |

```elixir
:telemetry.attach(
  "merchant-icons-counter",
  [:merchant_icons, :resolve],
  &MyApp.Metrics.handle_event/4,
  nil
)
```

The event never carries the description, the merchant or any other input. Validation errors and
`:ambiguous_merchant` do not emit events in this version. Your application decides whether to
attach a handler and what to do with the events; without a handler `resolve/1` behaves the same.
The library does not use `Logger`.

## How matching works

* **Normalization:** Unicode NFKD, accents removed, case folded, zero-width characters removed.
* **Tokens:** the text is split at separators and at letter/digit boundaries. CamelCase is not
  split, so `UberRides` is a single token.
* **Processor prefixes:** leading `dl`, `dm`, `ebn` or `ppro` tokens are ignored (also when
  repeated), so `DL * GOOGLE A0000021232` is matched as `GOOGLE A 0000021232`. Any other leading
  token (for example `PAYPAL`) is not skipped, and a prefix in the middle of a description is not
  ignored.
* **Aliases** are token sequences of two kinds:
  * `:leading`: the alias must start the description, and anything may follow it.
  * `:whole`: the alias must account for the whole description; only digits-only tokens may
    follow it. Used for short or generic names such as `Miro` or `Sentry`.
* **Conflicts:** the alias with more tokens wins, then `:whole` wins over `:leading`. If different
  merchants remain, the result is `:ambiguous_merchant`.

Matching is deterministic and there is **no substring matching**.

## Security and privacy

* Descriptions are untrusted: input is size-limited and validated before any processing, and
  nothing is built dynamically from it (no regex compilation from input, no `eval`).
* The description is never logged, stored, put in error messages, in the returned struct or in
  telemetry events.
* No network access and no persistence.

## Limitations

* **Small dataset:** it currently contains 109 merchants, and only five of them have an icon
  (Google, Adobe, OpenAI, Spotify and OpenRouter). The others return `icon: nil`.
* **Unknown merchants:** anything outside the dataset returns `{:ok, :unknown}`. Merchants are
  added to the library itself; there is no API for custom merchants or aliases yet.
* **Conservative matching:** because there is no substring matching, a name glued to a code (for
  example `GOOGLEADS 123`) or in the middle of a description (`MY GOOGLE`) is not matched. This
  avoids false positives at the cost of some false negatives.
* **Few processor prefixes:** only `dl`, `dm`, `ebn` and `ppro` are skipped.
* **Homoglyphs and non-Latin text:** Cyrillic or other look-alike letters are not mapped to Latin,
  and non-Latin descriptions are preserved as content and will usually be unknown.
* **Input limit:** 1024 bytes, provisional.
* **Telemetry:** only resolved and unknown results are reported.
