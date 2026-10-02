defmodule MerchantIcons.BundledIconsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias MerchantIcons.Data.Merchants
  alias MerchantIcons.Icons
  alias MerchantIcons.Merchant

  # These tests pin the business rules of the dataset: which merchant carries which icon, which
  # spellings of a description reach it, and which look-alikes must not. They are written to break
  # when a mapping is swapped, an alias changes kind, or the matching rules drift. Descriptions are
  # synthetic.

  @icons_dir Path.expand("../../priv/icons", __DIR__)

  # merchant id => icon file (without .svg). This is the contract: adding or changing an icon in
  # the dataset has to be mirrored here on purpose.
  @expected_icons %{
    "adobe" => "adobe",
    "airbnb" => "airbnb",
    "amazon" => "amazon_default",
    "anthropic" => "anthropic",
    "apple" => "apple",
    "atlassian" => "atlassian",
    "aws" => "aws_light",
    "clickup" => "clickup",
    "cloudflare" => "cloudflare",
    "cursor" => "cursor",
    "databricks" => "databricks",
    "facebook" => "facebook",
    "figma" => "figma",
    "github" => "github",
    "google" => "google",
    "google_one" => "google_one",
    "linkedin" => "linkedin",
    "manus_ai" => "manus_ai",
    "mercado_livre" => "mercado_libre",
    "mongodb" => "mongodb",
    "notion" => "notion",
    "openai" => "openai",
    "openrouter" => "openrouter_light",
    "replit" => "replit",
    "slack" => "slack",
    "spotify" => "spotify",
    "tiktok" => "tiktok",
    "twilio" => "twilio",
    "uber" => "uber_icon_light",
    "vercel" => "vercel",
    "lovable" => "lovable"
  }

  @prefixes ["DL", "DM", "EBN", "PPRO"]

  defp svg(file), do: File.read!(Path.join(@icons_dir, file <> ".svg"))

  defp resolve(description), do: MerchantIcons.resolve(description)

  defp resolved_id(description) do
    case resolve(description) do
      {:ok, %Merchant{id: id}} -> id
      {:ok, :unknown} -> :unknown
      {:error, code, _message} -> {:error, code}
    end
  end

  # ---------------------------------------------------------------------------------------------
  # The dataset and the icons directory agree
  # ---------------------------------------------------------------------------------------------

  describe "mapping of merchants to icon files" do
    test "the merchants with an icon are exactly the expected ones" do
      actual =
        for %{id: id, icon: icon} <- Merchants.all(), is_binary(icon), into: %{}, do: {id, icon}

      assert actual == @expected_icons
    end

    test "every svg in priv/icons belongs to a merchant, and the other way around" do
      files = @icons_dir |> Icons.files() |> Enum.map(&Path.basename(&1, ".svg")) |> Enum.sort()

      assert files == @expected_icons |> Map.values() |> Enum.sort()
    end

    test "no icon file is shared by two merchants" do
      files = Map.values(@expected_icons)

      assert length(files) == length(Enum.uniq(files))
    end

    test "no two icon files have the same content" do
      contents = for file <- Map.values(@expected_icons), do: svg(file)

      assert length(contents) == length(Enum.uniq(contents))
    end

    test "icon file names use only lowercase letters, digits and underscores" do
      for file <- Map.values(@expected_icons) do
        assert file =~ ~r/\A[a-z0-9_]+\z/, "#{file} is not a valid icon name"
      end
    end

    test "every bundled file is a plain svg: starts at <svg, has a viewBox, ends at </svg>" do
      for file <- Map.values(@expected_icons) do
        content = svg(file)

        assert String.starts_with?(content, "<svg"), "#{file} does not start with <svg"
        assert String.ends_with?(String.trim_trailing(content), "</svg>"), "#{file} end"
        assert content =~ "viewBox=", "#{file} has no viewBox"
        refute content =~ "<?xml", "#{file} has an xml declaration"
        refute content =~ "<!--", "#{file} has a comment"
        assert {:ok, ^content} = Icons.validate(content), "#{file} fails validation"
      end
    end
  end

  # ---------------------------------------------------------------------------------------------
  # Every merchant with an icon, every alias: spellings that must reach it
  # ---------------------------------------------------------------------------------------------

  defp fullwidth(text) do
    for <<char <- text>>, into: "" do
      cond do
        char in ?A..?Z -> <<char + 0xFEE0::utf8>>
        char in ?a..?z -> <<char + 0xFEE0::utf8>>
        true -> <<char>>
      end
    end
  end

  defp alternating_case(text) do
    text
    |> String.graphemes()
    |> Enum.with_index()
    |> Enum.map_join(fn {char, index} ->
      if rem(index, 2) == 0, do: String.upcase(char), else: String.downcase(char)
    end)
  end

  defp zero_width_inside_words(text) do
    text
    |> String.split(" ")
    |> Enum.map_join(" ", fn word ->
      {first, rest} = String.split_at(word, 1)
      first <> "" <> rest
    end)
  end

  defp title_case(text) do
    text |> String.split(" ") |> Enum.map_join(" ", &String.capitalize/1)
  end

  # Descriptions that must resolve to the merchant that owns `alias_text`.
  defp matching_variations(alias_text, kind) do
    up = String.upcase(alias_text)

    always = [
      {"as written", alias_text},
      {"upper case", up},
      {"title case", title_case(alias_text)},
      {"alternating case", alternating_case(alias_text)},
      {"surrounding spaces", "  " <> up <> "  "},
      {"words split by tabs", String.replace(up, " ", "\t")},
      {"words split by a star", String.replace(up, " ", " * ")},
      {"full-width letters", fullwidth(up)},
      {"zero-width characters inside words", zero_width_inside_words(up)},
      {"processor prefix DL", "DL * " <> up},
      {"processor prefix DM", "DM * " <> alias_text},
      {"processor prefix PPRO", "PPRO * " <> up},
      {"processor prefix EBN", "EBN * " <> up},
      {"repeated processor prefix", "DL * DM * " <> up},
      {"prefix without spaces", "DL*" <> up},
      {"code after the name", up <> " 0042"},
      {"long code after the name", up <> " 123456789012"},
      {"code glued to the name", up <> "123"},
      {"star then code", up <> " * 0042"}
    ]

    leading_only = [
      {"words after the name", up <> " SOME STORE BR"},
      {"alphanumeric code after the name", up <> " A1B2C3 BRASIL"},
      {"star then words", up <> "*TRIP"},
      {"prefix and words after", "DL * " <> up <> " SOME STORE"}
    ]

    case kind do
      :leading -> always ++ leading_only
      :whole -> always
    end
  end

  # Descriptions that must NOT resolve to the merchant that owns `alias_text`.
  defp rejected_variations(alias_text, kind, aliases) do
    all_aliases = for {text, _kind} <- aliases, do: text
    leading = for {text, :leading} <- aliases, do: text

    up = String.upcase(alias_text)
    first_word = up |> String.split(" ") |> hd()
    glued_words = String.replace(up, " ", "")

    common = [
      {"another leading token", "XY * " <> up},
      {"an unrelated processor", "PAYPAL * " <> up},
      {"a word before the name", "MY " <> up},
      {"a word glued before the name", "SUPER" <> up},
      {"the name in the middle", "SOME STORE " <> up},
      {"the name at the end", "SOME STORE " <> up <> " BR"},
      {"letters glued after the name", first_word <> "X"},
      {"the first word inside a longer word", first_word <> "ABA MATERIAIS"}
    ]

    whole_only = [
      {"words after a whole-description name", up <> " SERVICOS"},
      {"a word and a code after a whole-description name", up <> " SERVICOS 0042"}
    ]

    multi_word =
      if String.contains?(up, " ") do
        reversed = up |> String.split(" ") |> Enum.reverse() |> Enum.join(" ")
        extra = [{"words in reverse order", reversed}]

        # Skip the glued form when the dataset itself lists it as an alias of this merchant.
        if String.downcase(glued_words) in all_aliases do
          extra
        else
          [{"words glued together", glued_words} | extra]
        end
      else
        []
      end

    (common ++ multi_word ++ if(kind == :whole, do: whole_only, else: []))
    |> Enum.reject(fn {_label, description} ->
      starts_with_a_leading_alias?(description, leading)
    end)
  end

  # A description that begins with another `:leading` alias of the same merchant legitimately
  # resolves to it (for example `AWS AMAZON` starts with the `aws` alias), so it is not a
  # look-alike.
  defp starts_with_a_leading_alias?(description, leading_aliases) do
    normalized = String.downcase(description) <> " "

    Enum.any?(leading_aliases, &String.starts_with?(normalized, &1 <> " "))
  end

  describe "every alias of every merchant with an icon" do
    for %{id: id, icon: icon, aliases: aliases} <- Merchants.all(), is_binary(icon) do
      for {alias_text, kind} <- aliases do
        test "#{id}: #{inspect(alias_text)} (#{kind}) resolves with every spelling and carries the icon" do
          id = unquote(id)
          file = Map.fetch!(@expected_icons, id)
          expected_svg = svg(file)

          for {label, description} <-
                matching_variations(unquote(alias_text), unquote(kind)) do
            assert {:ok, %Merchant{} = merchant} = resolve(description),
                   "#{label}: #{inspect(description)} did not resolve"

            assert merchant.id == id,
                   "#{label}: #{inspect(description)} resolved to #{merchant.id}, not #{id}"

            assert merchant.icon == expected_svg,
                   "#{label}: #{inspect(description)} came back with the wrong svg"
          end
        end

        test "#{id}: #{inspect(alias_text)} (#{kind}) is not matched by look-alikes" do
          id = unquote(id)

          for {label, description} <-
                rejected_variations(unquote(alias_text), unquote(kind), unquote(aliases)) do
            refute resolved_id(description) == id,
                   "#{label}: #{inspect(description)} must not resolve to #{id}"
          end
        end
      end
    end
  end

  # ---------------------------------------------------------------------------------------------
  # Hand-written statements, independent of how the dataset spells its aliases
  # ---------------------------------------------------------------------------------------------

  describe "statement-like descriptions" do
    @statements [
      {"APPLE.COM/BILL", "apple"},
      {"APPLE.COM/BILL 866-712-7753", "apple"},
      {"APPLECOMBILL", "apple"},
      {"GITHUB, INC.", "github"},
      {"GITHUB * COPILOT", "github"},
      {"SLACK T0000000000", "slack"},
      {"DM * Slack T0000000000", "slack"},
      {"TWILIO", "twilio"},
      {"TWILIO SENDGRID", "twilio"},
      {"SENDGRID", "twilio"},
      {"MONGODB CLOUD", "mongodb"},
      {"MONGODBCLOUD", "mongodb"},
      {"MERCADOLIVRE*12345", "mercado_livre"},
      {"MERCADO LIVRE", "mercado_livre"},
      {"MERCADO * MERCADOLIVRE", "mercado_livre"},
      {"ANTHROPIC * CLAUDE TEAM", "anthropic"},
      {"CURSOR", "cursor"},
      {"CURSOR 0042", "cursor"},
      {"CURSOR AI", "cursor"},
      {"CURSOR AI POWERED IDE", "cursor"},
      {"GOOGLE ONE", "google_one"},
      {"GOOGLE ONE 2TB", "google_one"},
      {"GOOGLE *ONE", "google_one"},
      {"GOOGLE ADS 1234567890", "google"},
      {"GOOGLE CLOUD", "google"},
      {"GOOGLE", "google"},
      {"TIKTOK", "tiktok"},
      {"TikTok Ads", "tiktok"},
      {"TIKTOK PTE LTD", "tiktok"},
      {"TIKTOK*ADS", "tiktok"},
      {"AIRBNB * HM1A2B3C4D", "airbnb"},
      {"ATLASSIAN", "atlassian"},
      {"CLICKUP", "clickup"},
      {"CLOUDFLARE", "cloudflare"},
      {"DATABRICKS", "databricks"},
      {"FIGMA", "figma"},
      {"LINKEDIN", "linkedin"},
      {"MANUS AI", "manus_ai"},
      {"NOTION LABS", "notion"},
      {"REPLIT", "replit"},
      {"VERCEL INC", "vercel"}
    ]

    for {description, id} <- @statements do
      test "#{inspect(description)} resolves to #{id} with its own svg" do
        id = unquote(id)

        assert {:ok, %Merchant{id: ^id, icon: icon}} = resolve(unquote(description))
        assert icon == svg(Map.fetch!(@expected_icons, id))
      end
    end

    test "Google and Google One never trade icons" do
      assert {:ok, %Merchant{id: "google", icon: google}} = resolve("GOOGLE ADS 123")
      assert {:ok, %Merchant{id: "google_one", icon: one}} = resolve("GOOGLE ONE")

      assert google == svg("google")
      assert one == svg("google_one")
      assert google != one
    end

    test "Anthropic has an icon and Claude, its product, still has none" do
      assert {:ok, %Merchant{id: "anthropic", icon: icon}} = resolve("ANTHROPIC")
      assert is_binary(icon)

      assert {:ok, %Merchant{id: "claude", icon: nil}} = resolve("CLAUDE AI")
    end

    test "merchants that still have no icon return nil, not another merchant's icon" do
      for description <- ["TABOOLA", "KWAI", "STAPE", "SEMRUSH"] do
        assert {:ok, %Merchant{icon: nil}} = resolve(description),
               "#{description} unexpectedly has an icon"
      end
    end
  end

  describe "look-alike descriptions stay unknown" do
    @look_alikes [
      "PINEAPPLE STORE",
      "APPLEBEES",
      "GITLAB INC",
      "GITHUBX",
      "SLACKWARE",
      "NOTIONAL BANK",
      "TWILIGHT CAFE",
      "VERCELLI RESTAURANTE",
      "CURSORS",
      "CURSOR SERVICOS",
      "AIRBNBX",
      "TIK TOK",
      "MONGO DB",
      "LINKED IN",
      "FIGMAL",
      "CLOUDFLAREON"
    ]

    for description <- @look_alikes do
      test "#{inspect(description)} is unknown" do
        assert resolve(unquote(description)) == {:ok, :unknown}
      end
    end
  end

  # ---------------------------------------------------------------------------------------------
  # What the consumer renders
  # ---------------------------------------------------------------------------------------------

  describe "icon_data_uri/1 and the component for every merchant with an icon" do
    for {id, file} <- @expected_icons do
      test "#{id}: the data URI and the rendered image carry #{file}.svg" do
        file = unquote(file)
        description = "DL * " <> String.upcase(unquote(id) |> String.replace("_", " "))

        # `aws` has no alias that spells its id with a space, so resolve through the merchant.
        merchant =
          case resolve(description) do
            {:ok, %Merchant{id: unquote(id)} = merchant} ->
              merchant

            _other ->
              Enum.find_value(Merchants.all(), fn
                %{id: unquote(id), aliases: [{text, _kind} | _rest]} ->
                  {:ok, %Merchant{} = merchant} = resolve(text)
                  merchant

                _merchant ->
                  nil
              end)
          end

        assert merchant.id == unquote(id)
        assert merchant.icon == svg(file)

        encoded = Base.encode64(svg(file))
        assert MerchantIcons.icon_data_uri(merchant) == "data:image/svg+xml;base64," <> encoded

        html = render_component(&MerchantIcons.Components.merchant_icon/1, merchant: merchant)
        assert html =~ ~s|src="data:image/svg+xml;base64,#{encoded}"|
        assert html =~ ~s|alt="#{merchant.name}"|
      end
    end

    test "a merchant without an icon renders its initial, never an icon of another merchant" do
      html = render_component(&MerchantIcons.Components.merchant_icon/1, name: "TABOOLA")

      refute html =~ "<img"
      assert html =~ ">T</span>"
    end
  end

  describe "processor prefixes" do
    test "only the listed prefixes are skipped, for every merchant with an icon" do
      for %{id: id, icon: icon, aliases: [{text, _kind} | _rest]} <- Merchants.all(),
          is_binary(icon),
          prefix <- @prefixes ++ ["DLOCAL", "EBANX"] do
        description = prefix <> " * " <> String.upcase(text)

        assert resolved_id(description) == id, "#{inspect(description)} lost its merchant"
      end

      for %{id: id, icon: icon, aliases: aliases = [{text, _kind} | _rest]} <- Merchants.all(),
          is_binary(icon),
          prefix <- ["XX", "PAYPAL", "STRIPE", "MP"],
          # An alias written out with that prefix (`mp mercadolivre`) is a deliberate exception.
          String.downcase(prefix <> " " <> text) not in Enum.map(aliases, &elem(&1, 0)) do
        description = prefix <> " * " <> String.upcase(text)

        refute resolved_id(description) == id,
               "#{inspect(description)} must not skip the unlisted prefix #{prefix}"
      end
    end
  end
end
