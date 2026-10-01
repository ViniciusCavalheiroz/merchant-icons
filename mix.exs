defmodule MerchantIcons.MixProject do
  use Mix.Project

  def project do
    [
      app: :merchant_icons,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      # test/helpers holds modules loaded by test_helper.exs, not test files.
      test_ignore_filters: [&String.starts_with?(&1, "test/helpers/")],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 1.4.2"}
    ]
  end
end
