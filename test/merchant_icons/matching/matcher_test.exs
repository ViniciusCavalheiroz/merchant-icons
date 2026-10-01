defmodule MerchantIcons.Matching.MatcherTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Data.Merchants
  alias MerchantIcons.Matching.Index
  alias MerchantIcons.Matching.Matcher
  alias MerchantIcons.Matching.Normalizer
  alias MerchantIcons.Merchant
  alias MerchantIcons.Test.Helpers.FixtureMerchants, as: Fixture

  defp production, do: Index.build(Merchants.all())
  defp without_prefixes, do: Index.build(Merchants.all(), prefixes: [])

  defp match(description, index) do
    {:ok, tokens} = Normalizer.tokens(description)
    Matcher.match(tokens, index)
  end

  describe ":whole aliases" do
    test "match a description made only of the alias" do
      assert {:ok, %Merchant{id: "solo"}} = match("SOLO", Fixture.index())
      assert {:ok, %Merchant{id: "uber"}} = match("UberRides", production())
    end

    test "tolerate digits-only tokens after the alias" do
      assert {:ok, %Merchant{id: "solo"}} = match("SOLO 12345", Fixture.index())
      assert {:ok, %Merchant{id: "solo"}} = match("SOLO 1 22 333", Fixture.index())
      assert {:ok, %Merchant{id: "uber"}} = match("UBERRIDES 99", production())
    end

    test "do not tolerate other trailing words" do
      assert match("SOLO CREATIVE", Fixture.index()) == {:error, :unknown}
      assert match("SOLO 12 X", Fixture.index()) == {:error, :unknown}
      assert match("UberRides Trip", production()) == {:error, :unknown}
    end
  end

  describe ":leading aliases" do
    test "accept anything after the alias" do
      assert {:ok, %Merchant{id: "google"}} = match("GOOGLE ADS 12345678", production())
      assert {:ok, %Merchant{id: "uber"}} = match("Uber UBER * PENDING", production())
      assert {:ok, %Merchant{id: "adobe"}} = match("ADOBE * ADOBE", production())
    end

    test "must start the description" do
      assert match("MY GOOGLE", production()) == {:error, :unknown}
      assert match("SUPER UBER", production()) == {:error, :unknown}
      assert match("NOT ADOBE", production()) == {:error, :unknown}
    end

    test "compare whole tokens, never substrings or character prefixes" do
      assert match("UBERABA", production()) == {:error, :unknown}
      assert match("GOOGLEADS 123", production()) == {:error, :unknown}
      assert match("GOO", production()) == {:error, :unknown}
    end
  end

  describe "processor prefixes" do
    test "are skipped at the start of the description" do
      assert {:ok, %Merchant{id: "google"}} = match("DL * GOOGLE A0000000123", production())
      assert {:ok, %Merchant{id: "uber"}} = match("DL * UberRides", production())
      assert {:ok, %Merchant{id: "adobe"}} = match("PPRO * ADOBE", production())
      assert {:ok, %Merchant{id: "adobe"}} = match("EBN * ADOBE", production())
      assert {:ok, %Merchant{id: "slack"}} = match("DM * Slack T0000000000", production())
    end

    test "are not skipped when the index declares none" do
      assert match("DL * GOOGLE A0000000123", without_prefixes()) == {:error, :unknown}
    end

    test "consecutive prefixes are all skipped" do
      assert {:ok, %Merchant{id: "google"}} = match("DL DL * google", production())
    end

    test "are only recognised at the start" do
      assert {:ok, %Merchant{id: "google"}} = match("google DL", production())
      assert match("XY DL google", production()) == {:error, :unknown}
    end

    test "other leading tokens are not prefixes" do
      assert match("PAYPAL * GITHUB INC", production()) == {:error, :unknown}
      assert match("XY * GOOGLE A0000000123", production()) == {:error, :unknown}
    end

    test "a prefix with nothing after it is unknown" do
      assert match("DL *", production()) == {:error, :unknown}
    end
  end

  describe "priority" do
    test "the alias with more tokens wins" do
      assert {:ok, %Merchant{id: "acme_foods"}} = match("ACME FOODS 77", Fixture.index())
    end

    test ":whole wins over :leading when both fit equally" do
      assert {:ok, %Merchant{id: "orbit_whole"}} = match("ORBIT", Fixture.index())
      assert {:ok, %Merchant{id: "orbit_whole"}} = match("ORBIT 123", Fixture.index())
    end

    test ":leading is used when the :whole alias does not fit" do
      assert {:ok, %Merchant{id: "orbit_leading"}} = match("ORBIT EXTRA", Fixture.index())
    end
  end

  describe "ambiguity" do
    test "different merchants with the same priority are ambiguous" do
      assert match("ACME", Fixture.index()) == {:error, :ambiguous}
      assert match("ACME 77", Fixture.index()) == {:error, :ambiguous}
    end

    test "a merchant that does not share the alias is not affected" do
      assert {:ok, %Merchant{id: "orbit_whole"}} = match("ORBIT", Fixture.index())
      assert {:ok, %Merchant{id: "solo"}} = match("SOLO", Fixture.index())
    end
  end

  describe "unknown descriptions" do
    test "content without a known alias" do
      assert match("PADARIA DO ZE 0042", production()) == {:error, :unknown}
    end

    test "content without tokens" do
      assert match("***", production()) == {:error, :unknown}
      assert match("***", Fixture.index()) == {:error, :unknown}
    end
  end

  test "matching is deterministic" do
    for _ <- 1..5 do
      assert match("ACME FOODS", Fixture.index()) == match("ACME FOODS", Fixture.index())
    end
  end
end
