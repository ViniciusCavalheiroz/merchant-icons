defmodule Iconify.MerchantIconTest do
  use ExUnit.Case, async: true

  alias Iconify.Merchant

  # The file is read from the application's priv directory, the same place the library compiles
  # its icons from, so no machine-specific path is involved.
  defp spotify_svg do
    :iconify
    |> Application.app_dir("priv/icons/spotify.svg")
    |> File.read!()
  end

  describe "a merchant with an icon" do
    test "resolves to Spotify" do
      assert {:ok, %Merchant{} = merchant} = Iconify.resolve("SPOTIFY")

      assert merchant.id == "spotify"
      assert merchant.name == "Spotify"
    end

    test "the icon is the packaged SVG itself" do
      {:ok, %Merchant{icon: icon}} = Iconify.resolve("SPOTIFY")

      assert is_binary(icon)
      assert icon == spotify_svg()
    end

    test "the icon is real markup, not a slug, a path or a URL" do
      {:ok, %Merchant{icon: icon}} = Iconify.resolve("SPOTIFY")

      refute icon == "spotify"
      refute icon =~ "priv/icons"
      refute String.starts_with?(icon, ["http:", "https:", "/"])
      assert String.starts_with?(icon, "<svg")
      assert icon =~ "viewBox="
    end

    test "noisy descriptions of the same merchant carry the same icon" do
      for description <- ["Spotify", "DL * SPOTIFY P1234ABCD", "spotify 0042", "PPRO * Spotify"] do
        assert {:ok, %Merchant{id: "spotify", icon: icon}} = Iconify.resolve(description)
        assert icon == spotify_svg()
      end
    end

    test "inspect does not print the markup" do
      {:ok, merchant} = Iconify.resolve("SPOTIFY")

      refute inspect(merchant) =~ "<svg"
    end
  end

  describe "a merchant without an icon" do
    test "has icon: nil, never a missing path or an external URL" do
      assert {:ok, %Merchant{id: "google", icon: nil}} = Iconify.resolve("Google ADS2397919998")
    end
  end

  describe "icons across the dataset" do
    test "every resolvable merchant has a validated SVG or nil, never anything else" do
      descriptions = ["SPOTIFY", "Google", "Uber", "ADOBE", "Slack", "GitHub", "Notion"]

      for description <- descriptions do
        {:ok, %Merchant{icon: icon}} = Iconify.resolve(description)

        assert is_nil(icon) or Iconify.Icons.validate(icon) == {:ok, icon},
               "unexpected icon for #{inspect(description)}"
      end
    end

    test "the packaged Spotify SVG passes validation" do
      svg = spotify_svg()

      assert Iconify.Icons.validate(svg) == {:ok, svg}
    end
  end
end
