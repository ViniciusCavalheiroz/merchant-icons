defmodule MerchantIcons.IconVariationsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MerchantIcons.Merchant

  # Descriptions are synthetic. Each group lists variations of how one merchant can appear in a
  # statement and the exact icon file that must come with it. The icon is compared with the file
  # in priv/icons, so a merchant that resolves but carries the wrong svg fails too.

  @icons_dir Path.expand("../../priv/icons", __DIR__)

  defp svg(file), do: File.read!(Path.join(@icons_dir, file <> ".svg"))

  defp resolve!(description) do
    assert {:ok, %Merchant{} = merchant} = MerchantIcons.resolve(description)
    merchant
  end

  @uber [
    "Uber",
    "UBER",
    "uber",
    "  Uber  ",
    "Uber UBER * PENDING",
    "Uber Trip Help",
    "UBER TRIP 12345",
    "UBER*TRIP",
    "UBER * TRIP",
    "UBER   TRIP",
    "UBER *EATS",
    "Uber.com",
    "uber 1234",
    "ÜBER",
    "DL * UberRides",
    "UberRides",
    "UBERRIDES 12345",
    "DM * UBER",
    "PPRO * UBER TRIP",
    "DL * DL * UBER"
  ]

  @amazon [
    "Amazon",
    "AMAZON",
    "amazon",
    "Amazon.com",
    "amazon.com.br",
    "Amazon BR",
    "Amazon Marketplace",
    "AMAZON MARKETPLACE 12345",
    "AMAZON PRIME",
    "Amazon Prime Video",
    "AMAZON *1A2B3C4D",
    "AMAZON * 1A2B3C4D",
    "Amazon  Servicos de Varejo",
    "AMAZONMKTPLC",
    "AMAZONMKTPLC 12345",
    "DL * AMAZON",
    "PPRO * AMAZON BR"
  ]

  @aws [
    "AWS",
    "aws",
    "Aws",
    "AWS EMEA",
    "AWS 12345",
    "AWS * EMEA",
    "Amazon AWS",
    "AMAZON AWS",
    "amazon aws",
    "Amazon AWS Servicos Br",
    "AMAZON AWS SERVICES XX",
    "Amazon * AWS",
    "Amazon-AWS",
    "AMAZON AWS 12345",
    "Amazon Web Services",
    "AMAZON WEB SERVICES",
    "Amazon Web Services EMEA",
    "amazon web services 12345",
    "DL * AMAZON AWS",
    "PPRO * AWS EMEA"
  ]

  @facebook_names [
    "Facebook",
    "FACEBOOK",
    "facebook",
    "FACEBK",
    "facebk",
    "Facebook Ads",
    "FACEBOOK ADS 12345",
    "FACEBK * XX00YY00ZZ",
    "FACEBK *XX00YY00ZZ",
    "FACEBK * TEMP HOLD ZZZZ",
    "DL * FACEBK * XX00YY00ZZ",
    "PPRO * FACEBOOK"
  ]

  # Descriptions that carry "aws" inside a code or at another position, where it must not take
  # over. Matching is anchored at the start of the description: the first token decides.
  @facebook [
    "FACEBK * QXH8G5AWS4",
    "FACEBK * AWS4",
    "FACEBK * AWS",
    "FACEBK *QXH8G5AWS4",
    "facebk * qxh8g5aws4",
    "Facebook AWS Ads",
    "DL * FACEBK * QXH8G5AWS4"
  ]

  @unknown [
    "AWSOME STORE",
    "AWSEMEA",
    "AMAZONAWS",
    "PAGTO AWS",
    "MY AWS",
    "XYZ8AWS4",
    "SUPER UBER",
    "NOT AMAZON",
    "MY AMAZON STORE",
    "UBERABA MATERIAIS",
    "AMAZONIA BAR"
  ]

  describe "Uber" do
    for description <- @uber do
      test "#{inspect(description)} resolves to Uber with the Uber icon" do
        merchant = resolve!(unquote(description))

        assert merchant.id == "uber"
        assert merchant.name == "Uber"
        assert merchant.icon == svg("uber_icon_light")
      end
    end
  end

  describe "Amazon" do
    for description <- @amazon do
      test "#{inspect(description)} resolves to Amazon with the Amazon icon" do
        merchant = resolve!(unquote(description))

        assert merchant.id == "amazon"
        assert merchant.name == "Amazon"
        assert merchant.icon == svg("amazon_default")
      end
    end
  end

  describe "AWS" do
    for description <- @aws do
      test "#{inspect(description)} resolves to AWS with the AWS icon" do
        merchant = resolve!(unquote(description))

        assert merchant.id == "aws"
        assert merchant.name == "AWS"
        assert merchant.icon == svg("aws_light")
      end
    end
  end

  describe "Facebook" do
    for description <- @facebook_names do
      test "#{inspect(description)} resolves to Facebook with the Facebook icon" do
        merchant = resolve!(unquote(description))

        assert merchant.id == "facebook"
        assert merchant.name == "Facebook"
        assert merchant.icon == svg("facebook")
      end
    end
  end

  describe "aws inside another description" do
    for description <- @facebook do
      test "#{inspect(description)} stays Facebook and never gets the AWS icon" do
        merchant = resolve!(unquote(description))

        assert merchant.icon != svg("aws_light")
        assert merchant.icon != svg("amazon_default")

        assert merchant.id == "facebook"
        assert merchant.name == "Facebook"
        assert merchant.icon == svg("facebook")
      end
    end
  end

  describe "descriptions that must not match" do
    for description <- @unknown do
      test "#{inspect(description)} is unknown" do
        assert MerchantIcons.resolve(unquote(description)) == {:ok, :unknown}
      end
    end
  end

  describe "the new icons" do
    test "are different files with valid content" do
      icons = Enum.map(["uber_icon_light", "amazon_default", "aws_light", "facebook"], &svg/1)

      assert length(Enum.uniq(icons)) == 4

      for icon <- icons do
        assert {:ok, ^icon} = MerchantIcons.Icons.validate(icon)
      end
    end

    test "Amazon and AWS never share an icon" do
      assert resolve!("Amazon").icon != resolve!("Amazon AWS").icon
      assert resolve!("Amazon Marketplace").icon != resolve!("Amazon Web Services").icon
    end

    test "icon_data_uri/1 returns the data URI of each icon" do
      for {description, file} <- [
            {"Uber", "uber_icon_light"},
            {"Amazon", "amazon_default"},
            {"Amazon AWS Servicos Br", "aws_light"},
            {"FACEBK * XX00YY00ZZ", "facebook"}
          ] do
        uri = description |> resolve!() |> MerchantIcons.icon_data_uri()

        assert uri == "data:image/svg+xml;base64," <> Base.encode64(svg(file))
      end
    end
  end

  describe "the component renders the right svg" do
    defp rendered_svg(name) do
      html = render_component(&MerchantIcons.Components.merchant_icon/1, name: name)
      [_whole, encoded] = Regex.run(~r/src="data:image\/svg\+xml;base64,([^"]+)"/, html)

      Base.decode64!(encoded)
    end

    test "Uber" do
      assert rendered_svg("DL * UberRides") == svg("uber_icon_light")
    end

    test "Amazon" do
      assert rendered_svg("Amazon Marketplace") == svg("amazon_default")
    end

    test "AWS" do
      assert rendered_svg("Amazon AWS Servicos Br") == svg("aws_light")
      assert rendered_svg("AWS EMEA") == svg("aws_light")
    end

    test "Facebook, including when aws is part of its code" do
      assert rendered_svg("FACEBK * XX00YY00ZZ") == svg("facebook")
      assert rendered_svg("FACEBK * QXH8G5AWS4") == svg("facebook")
    end

    test "a merchant that still has no icon shows its initial" do
      html = render_component(&MerchantIcons.Components.merchant_icon/1, name: "Taboola")

      refute html =~ "<img"
      assert html =~ ">T</span>"
    end
  end
end
