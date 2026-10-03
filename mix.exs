defmodule MerchantIcons.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/ViniciusCavalheiroz/merchant-icons"

  def project do
    [
      app: :merchant_icons,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      # test/helpers holds modules loaded by test_helper.exs, not test files.
      test_ignore_filters: [&String.starts_with?(&1, "test/helpers/")],
      description: description(),
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
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
      maintainers: ["Vinicius Cavalheiro Martins da Luz"],
      files: ~w(lib priv/icons/*.svg mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "MerchantIcons",
      source_ref: "v#{@version}",
      extras: ["README.md", "LICENSE"],
      groups_for_modules: [
        API: [MerchantIcons],
        Components: [MerchantIcons.Components],
        Data: [MerchantIcons.Merchant]
      ],
      skip_undefined_reference_warnings_on: ["README.md"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.4.2"},
      # Optional: only needed by MerchantIcons.Components. Consumers that use the
      # lib purely as a resolver do not pull Phoenix in. Available in this lib's
      # own build and tests so the component compiles and is tested here.
      {:phoenix_live_view, "~> 1.1 and >= 1.1.28", optional: true},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:benchee, "~> 1.5", only: :dev, runtime: false}
    ]
  end
end
