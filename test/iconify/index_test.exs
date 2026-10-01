defmodule Iconify.IndexTest do
  use ExUnit.Case, async: true

  alias Iconify.Index
  alias Iconify.Matcher
  alias Iconify.Merchant
  alias Iconify.Normalizer

  defp valid(overrides \\ %{}) do
    Map.merge(%{id: "ok", name: "Ok", icon: "ok", aliases: [{"ok", :whole}]}, overrides)
  end

  defp assert_invalid(definitions, opts \\ []) do
    assert_raise ArgumentError, fn -> Index.build(definitions, opts) end
  end

  defp match(description, index) do
    {:ok, tokens} = Normalizer.tokens(description)
    Matcher.match(tokens, index)
  end

  describe "accepted definitions" do
    test "aliases are normalized the same way as descriptions" do
      index =
        Index.build([
          valid(%{id: "uber", name: "Uber", aliases: [{"UberRides", :whole}]}),
          valid(%{id: "bank", name: "Bank", aliases: [{"C6 Bank", :whole}]}),
          valid(%{id: "tel", name: "Tel", aliases: [{"AT&T", :leading}]})
        ])

      assert {:ok, %Merchant{id: "uber"}} = match("uberrides 99", index)
      assert {:ok, %Merchant{id: "bank"}} = match("c6bank", index)
      assert {:ok, %Merchant{id: "bank"}} = match("C6 BANK 12", index)
      assert {:ok, %Merchant{id: "tel"}} = match("at&t wireless", index)
      assert {:ok, %Merchant{id: "tel"}} = match("AT T", index)
    end

    test "the merchant is returned as defined, and the icon is optional" do
      with_icon = Index.build([valid()])
      no_icon = Index.build([Map.delete(valid(), :icon)])

      assert match("ok", with_icon) == {:ok, %Merchant{id: "ok", name: "Ok", icon: "ok"}}
      assert match("ok", no_icon) == {:ok, %Merchant{id: "ok", name: "Ok", icon: nil}}
    end

    test "ids in snake_case ASCII are accepted" do
      for id <- ["google", "c6_bank", "7_eleven", "a1"] do
        assert %Index{} = Index.build([valid(%{id: id, aliases: [{"alias", :whole}]})])
      end
    end

    test "processor prefixes only apply when declared" do
      plain = Index.build([valid()], prefixes: [])
      declared = Index.build([valid()], prefixes: ["DL"])

      assert match("dl ok", plain) == {:error, :unknown}
      assert {:ok, %Merchant{id: "ok"}} = match("dl ok", declared)
    end

    test "the same alias may belong to several merchants, which is reported as ambiguous" do
      index =
        Index.build([
          valid(%{id: "a", aliases: [{"shared", :leading}]}),
          valid(%{id: "b", aliases: [{"shared", :leading}]})
        ])

      assert match("shared", index) == {:error, :ambiguous}
    end
  end

  describe "rejected merchants" do
    test "ids must be snake_case ASCII" do
      ids = ["Google", "google ads", "google__ads", "_google", "google_", "", "gøgle", "goo-gle"]

      for id <- ids do
        assert_invalid([valid(%{id: id})])
      end
    end

    test "ids must be unique" do
      assert_invalid([valid(), valid(%{aliases: [{"other", :whole}]})])
    end

    test "id and name must be binaries, and the name must not be blank" do
      assert_invalid([valid(%{id: :ok})])
      assert_invalid([valid(%{id: nil})])
      assert_invalid([valid(%{name: "   "})])
      assert_invalid([valid(%{name: 1})])
      assert_invalid([Map.delete(valid(), :name)])
      assert_invalid([:not_a_map])
    end

    test "the icon must be a binary or nil" do
      assert_invalid([valid(%{icon: 1})])
      assert_invalid([valid(%{icon: :ok})])
      assert %Index{} = Index.build([valid(%{icon: nil})])
    end
  end

  describe "rejected aliases" do
    test "aliases must be a non-empty list" do
      assert_invalid([valid(%{aliases: []})])
      assert_invalid([Map.delete(valid(), :aliases)])
    end

    test "aliases must be {binary, :whole | :leading}" do
      assert_invalid([valid(%{aliases: ["ok"]})])
      assert_invalid([valid(%{aliases: [{"ok", :other}]})])
      assert_invalid([valid(%{aliases: [{:ok, :whole}]})])
    end

    test "aliases must normalize to at least one token" do
      assert_invalid([valid(%{aliases: [{"***", :whole}]})])
      assert_invalid([valid(%{aliases: [{"   ", :whole}]})])
      assert_invalid([valid(%{aliases: [{"", :whole}]})])
    end

    test "aliases that are too large or not valid UTF-8 are rejected" do
      assert_invalid([valid(%{aliases: [{String.duplicate("a", 1025), :whole}]})])
      assert_invalid([valid(%{aliases: [{<<0xFF>>, :whole}]})])
    end

    test "aliases made only of digits are rejected" do
      assert_invalid([valid(%{aliases: [{"0042", :whole}]})])
      assert_invalid([valid(%{aliases: [{"12 34", :leading}]})])
    end

    test "aliases may not start with a processor prefix" do
      assert_invalid([valid(%{aliases: [{"dl hardware", :whole}]})], prefixes: ["dl"])
    end

    test "the same alias twice in one merchant is rejected, whatever its spelling or kind" do
      assert_invalid([valid(%{aliases: [{"uber", :leading}, {"UBER", :whole}]})])
    end
  end

  describe "rejected processor prefixes" do
    test "entries must normalize to exactly one token" do
      assert_invalid([valid()], prefixes: ["two words"])
      assert_invalid([valid()], prefixes: [""])
      assert_invalid([valid()], prefixes: ["***"])
      assert_invalid([valid()], prefixes: [:dl])
    end
  end
end
