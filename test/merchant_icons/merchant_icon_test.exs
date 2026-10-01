defmodule MerchantIcons.MerchantIconTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Data.Merchants
  alias MerchantIcons.Icons
  alias MerchantIcons.Merchant

  @required_icons ~w(adobe google openai spotify)

  @with_icon for merchant <- Merchants.all(), is_binary(merchant.icon), do: merchant
  @without_icon for merchant <- Merchants.all(), is_nil(merchant.icon), do: merchant

  defp svg_file(icon_name) do
    :merchant_icons
    |> Application.app_dir(Path.join("priv/icons", icon_name <> ".svg"))
    |> File.read!()
  end

  defp description(%{aliases: [{alias_text, _kind} | _rest]}), do: alias_text

  describe "dataset" do
    test "the required icons are all wired to a merchant" do
      with_icon = Enum.map(@with_icon, & &1.id)

      assert @required_icons -- with_icon == []
    end

    test "every referenced icon name is a file in priv/icons, and every file is referenced" do
      referenced = @with_icon |> Enum.map(& &1.icon) |> Enum.uniq() |> Enum.sort()

      files =
        :merchant_icons
        |> Application.app_dir("priv/icons")
        |> Icons.files()
        |> Enum.map(&Path.basename(&1, ".svg"))

      assert files == referenced
    end
  end

  describe "merchants with an icon" do
    for merchant <- @with_icon do
      @merchant merchant

      test "#{merchant.id}: resolves with the packaged SVG as its icon" do
        merchant = @merchant

        assert {:ok, %Merchant{} = resolved} = MerchantIcons.resolve(description(merchant))

        assert resolved.id == merchant.id
        assert resolved.name == merchant.name
        assert resolved.icon == svg_file(merchant.icon)
      end

      test "#{merchant.id}: the icon is validated markup, not an icon name, a path or a URL" do
        merchant = @merchant

        {:ok, %Merchant{icon: icon}} = MerchantIcons.resolve(description(merchant))

        assert Icons.validate(icon) == {:ok, icon}
        refute icon == merchant.icon
        refute icon =~ "priv/icons"
        refute String.starts_with?(icon, ["http:", "https:", "/"])
      end

      test "#{merchant.id}: a noisy description carries the same icon" do
        merchant = @merchant
        noisy = "DL * " <> String.upcase(description(merchant)) <> " 0042"

        assert {:ok, %Merchant{id: id, icon: icon}} = MerchantIcons.resolve(noisy)

        assert id == merchant.id
        assert icon == svg_file(merchant.icon)
      end

      test "#{merchant.id}: inspect does not print the markup" do
        merchant = @merchant

        {:ok, resolved} = MerchantIcons.resolve(description(merchant))

        refute inspect(resolved) =~ "<svg"
      end
    end
  end

  describe "merchants without an icon" do
    test "have icon: nil, never a missing path or an external URL" do
      for merchant <- @without_icon do
        assert {:ok, %Merchant{id: id, icon: nil}} = MerchantIcons.resolve(description(merchant))
        assert id == merchant.id
      end
    end
  end
end
