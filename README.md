# Iconify

Iconify is an Elixir library for identifying merchants from transaction descriptions and providing the data required to display their corresponding icons.

The library receives only the transaction description and returns the identified merchant, including its identifier, name, and icon.

```elixir
Iconify.resolve("Spotify")
```

```elixir
{:ok, %Iconify.Merchant{
  id: "spotify",
  name: "Spotify",
  icon: "spotify"
}}
```

Icons are bundled with the library and stored as SVG files under `priv/icons`.

The consuming application does not need to fetch icons from external services or access the internet to retrieve them.

## Features

* Identify merchants from transaction descriptions.
* Normalize transaction descriptions.
* Support merchant aliases and different description formats.
* Handle payment processor prefixes.
* Detect ambiguous merchant matches.
* Bundle merchant icons as SVG files.
* No network dependencies.
* Simple API for Elixir applications.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding `iconify` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:iconify, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Usage

Resolve a merchant from a description:

```elixir
Iconify.resolve("OPENAI * CHATGPT SUBSCR")
```

```elixir
{:ok, %Iconify.Merchant{
  id: "openai",
  name: "OpenAI",
  icon: "openai"
}}
```

Another example:

```elixir
Iconify.resolve("DL * GOOGLE A000000")
```

```elixir
{:ok, %Iconify.Merchant{
  id: "google",
  name: "Google",
  icon: "google"
}}
```

When the merchant cannot be identified:

```elixir
Iconify.resolve("UNKNOWN MERCHANT")
```

```elixir
{:error, :unknown_merchant, "Merchant not identified"}
```

## Icons

Merchant icons are included in the package as SVG files under:

```text
priv/icons/
```

The `icon` field returned by `Iconify.resolve/1` identifies the corresponding icon.

For example:

```elixir
merchant.icon
#=> "spotify"
```

The application can use this identifier to locate the corresponding SVG included with Iconify.

## Scope

Iconify is responsible for identifying merchants and providing the corresponding icon.

It does not process or interpret:

* transaction amounts;
* currencies;
* categories;
* MCC;
* countries;
* financial rules;
* payment processing;
* external image services.

The library does not download or resolve images from the internet.

## Development

Format the code:

```bash
mix format
```

Run the test suite:

```bash
mix test
```

Generate the documentation:

```bash
mix docs
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm/).

Once published, the documentation will be available at:

https://hexdocs.pm/iconify
