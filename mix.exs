defmodule MerchantIcons.MixProject do
  use Mix.Project

  @source_url "https://github.com/ViniciusCavalheiroz/merchant-icons"

  def project do
    [
      app: :merchant_icons,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      # test/helpers holds modules loaded by test_helper.exs, not test files.
      test_ignore_filters: [&String.starts_with?(&1, "test/helpers/")],
      description: description(),
      package: package(),
      source_url: @source_url,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Resolves noisy transaction descriptions to a known merchant and its bundled SVG icon. " <>
      "Offline, stateless and safe by design."
  end

  # `files` is explicit so stray files such as README.md.save never reach the package.
  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv/icons mix.exs README.md)
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.4.2"}
    ]
  end
end
