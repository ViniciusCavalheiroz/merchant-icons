defmodule MerchantIcons.MatchingPrecisionTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Merchant

  # Synthetic descriptions that reproduce the shapes of mismatches found when the matching was
  # audited against real statements. Nothing here comes from a real statement: names are the
  # merchants' own, codes and suffixes are made up. Each group states the rule behind it.

  @icons_dir Path.expand("../../priv/icons", __DIR__)

  defp svg(file), do: File.read!(Path.join(@icons_dir, file <> ".svg"))

  defp resolved_id(description) do
    case MerchantIcons.resolve(description) do
      {:ok, %Merchant{id: id}} -> id
      {:ok, :unknown} -> :unknown
      {:error, code, _message} -> {:error, code}
    end
  end

  defp icon(description) do
    {:ok, %Merchant{icon: icon}} = MerchantIcons.resolve(description)
    icon
  end

  # ---------------------------------------------------------------------------------------------
  # Google One against Google, Google Play and the other Google products
  # ---------------------------------------------------------------------------------------------

  describe "Google One" do
    test "plain spellings resolve to Google One with its own icon" do
      for description <- [
            "Google One",
            "GOOGLE ONE",
            "google one",
            "Google * One",
            "Google One 2TB"
          ] do
        assert resolved_id(description) == "google_one", description
        assert icon(description) == svg("google_one"), description
      end
    end

    test "a processor prefix followed by GOOGLE and the product name still is Google One" do
      # The descriptor repeats the word: `<prefix> * GOOGLE Google One` has the tokens
      # `google google one`.
      for description <- [
            "DL * GOOGLE Google One",
            "DL * Google Google One",
            "DM * GOOGLE GOOGLE ONE",
            "DLOCAL * GOOGLE Google One",
            "EBN * GOOGLE Google One",
            "DL * DL * GOOGLE Google One",
            "dl * google google one 0042"
          ] do
        assert resolved_id(description) == "google_one", description
        assert icon(description) == svg("google_one"), description
      end
    end

    test "other Google products are Google, not Google One" do
      for description <- [
            "DL * GOOGLE Google",
            "DL * GOOGLE Workspace_synthetic",
            "DL * GOOGLE GSUITE_synthetic",
            "DL * GOOGLE CLOUD",
            "DL * GOOGLE ADS1234567890",
            "Google ADS1234567890",
            "GOOGLE * PLAY",
            "Google Play Pass",
            "Google Chrome Extension",
            "Google Storage",
            "Google Payments Temp"
          ] do
        assert resolved_id(description) == "google", description
        assert icon(description) == svg("google"), description
      end
    end

    test "words that only start like 'one' do not make a Google description Google One" do
      for description <- [
            "Google ONEDRIVE",
            "Google ONEX",
            "DL * GOOGLE ONEPLUS",
            "Google Ones",
            "Google Phone"
          ] do
        assert resolved_id(description) == "google", description
      end
    end

    test "'one' alone or away from the Google name is not Google One" do
      for description <- ["ONE", "ONE GOOGLE", "MY GOOGLE ONE", "ONE * GOOGLE", "XY * Google One"] do
        refute resolved_id(description) == "google_one", description
      end
    end

    test "Google and Google One never trade icons and never become ambiguous" do
      assert {:ok, %Merchant{id: "google"}} = MerchantIcons.resolve("DL * GOOGLE Google")
      assert {:ok, %Merchant{id: "google_one"}} = MerchantIcons.resolve("DL * GOOGLE Google One")
      assert svg("google") != svg("google_one")
    end
  end

  # ---------------------------------------------------------------------------------------------
  # `<processor> * <merchant>` forms that were unknown
  # ---------------------------------------------------------------------------------------------

  describe "the long spellings of processors already skipped as prefixes" do
    test "DLOCAL is DL and EBANX is EBN" do
      assert resolved_id("DLOCAL * GOOGLE WORKSPACE") == "google"
      assert resolved_id("dlocal * Google Ads 123") == "google"
      assert resolved_id("EBANX * ADOBE") == "adobe"
      assert resolved_id("Ebanx * TikTok Ads") == "tiktok"
      assert resolved_id("EBANX * HOSTINGER") == "hostinger"
      assert resolved_id("EBANX * EBN * ADOBE") == "adobe"
      assert resolved_id("DL * EBANX * ADOBE") == "adobe"
    end

    test "the processor on its own, or followed by an unknown name, stays unknown" do
      for description <- [
            "DLOCAL",
            "EBANX",
            "DLOCAL 123",
            "EBANX PAGAMENTOS",
            "EBANX * SOME UNKNOWN STORE",
            "DLOCAL * ANOTHER UNKNOWN STORE"
          ] do
        assert resolved_id(description) == :unknown, description
      end
    end

    test "they are prefixes only at the start of the description" do
      assert resolved_id("ADOBE * EBANX") == "adobe"
      assert resolved_id("SOME STORE * EBANX * ADOBE") == :unknown
      assert resolved_id("MY DLOCAL * GOOGLE") == :unknown
    end

    test "a name glued to the processor is not a prefix" do
      assert resolved_id("EBANXADOBE") == :unknown
      assert resolved_id("DLOCALGOOGLE") == :unknown
    end
  end

  describe "processors that are not skipped, with the merchant spelled out as an alias" do
    test "PG * ZapSign resolves, other PG descriptions and other prefixes do not" do
      assert resolved_id("PG * ZAPSIGN") == "zapsign"
      assert resolved_id("pg * zapsign 123") == "zapsign"
      assert resolved_id("DL * PG * ZAPSIGN") == "zapsign"

      assert resolved_id("PG * ZAPSIGNX") == :unknown
      assert resolved_id("PG * SOME OTHER STORE") == :unknown
      assert resolved_id("EC * ZAPSIGN") == :unknown
      assert resolved_id("PAYPAL * ZAPSIGN") == :unknown
      assert resolved_id("PG ZAPSIGN") == "zapsign"
    end

    test "PG is still not a processor prefix for the other merchants" do
      for merchant <- ["GOOGLE", "ADOBE", "UBER", "GITHUB", "FACEBK"] do
        assert resolved_id("PG * " <> merchant) == :unknown, merchant
      end
    end

    test "EC and MP followed by the marketplace name resolve to Mercado Livre" do
      for description <- ["EC * MERCADOLIVRE", "MP * MERCADOLIVRE", "mp * mercadolivre 123"] do
        assert resolved_id(description) == "mercado_livre", description
        assert icon(description) == svg("mercado_libre"), description
      end
    end

    test "EC and MP followed by anything else stay unknown" do
      for description <- [
            "EC * SOME SELLER",
            "MP * SOME SELLER",
            "MP * MP",
            "EC * MERCADO",
            "PG * MERCADOLIVRE",
            "PAYPAL * MERCADOLIVRE"
          ] do
        assert resolved_id(description) == :unknown, description
      end
    end

    test "'MERCADO * seller' stays unknown: the star cannot be told from a space" do
      # `MERCADO * SELLER` and `MERCADO CENTRAL` have the same tokens, so no rule can send the
      # first one to Mercado Livre without sending the second one too.
      assert resolved_id("MERCADO * SOME SELLER") == :unknown
      assert resolved_id("MERCADO CENTRAL") == :unknown
    end

    test "FC and MGF followed by Freepik resolve to Freepik" do
      for description <- [
            "FC * FREEPIK PREMIUM",
            "FC * FREEPIK PRO MONTHLY",
            "MGF * FREEPIK PREMIUM",
            "mgf * freepik 123",
            "FREEPIK COMPANY"
          ] do
        assert resolved_id(description) == "freepik", description
      end
    end

    test "FC and MGF followed by anything else stay unknown, and MGF still reaches Magnific" do
      assert resolved_id("FC * SOME STORE") == :unknown
      assert resolved_id("MGF * SOME STORE") == :unknown
      assert resolved_id("FC * FREEPIKX") == :unknown
      assert resolved_id("XY * FREEPIK") == :unknown
      assert resolved_id("MGF * MAGNIFIC PREMIUM") == "magnific"
    end

    test "Cakto and CKT forms resolve to Octuz AI" do
      for description <- [
            "CAKTO PAY LT * OCTUZ AI",
            "CKT * * CREDITOS OCTUZ",
            "CKT * * OCTUZ AI",
            "ckt * creditos octuz 123"
          ] do
        assert resolved_id(description) == "octuz_ai", description
      end

      for description <- [
            "CAKTO PAY LT * SOME STORE",
            "CAKTO PAY * OCTUZ AI",
            "CKT * * CREDITOS SOME STORE",
            "CKT * * SOME STORE"
          ] do
        assert resolved_id(description) == :unknown, description
      end
    end

    test "Vindi followed by the Clicksign product resolves to Clicksign" do
      assert resolved_id("Vindi * ClicksignGesta") == "clicksign"
      assert resolved_id("VINDI * CLICKSIGNGESTA 12") == "clicksign"
      assert resolved_id("CLICKSIGN * Clicksign") == "clicksign"

      assert resolved_id("Vindi * ClicksignGestao") == :unknown
      assert resolved_id("Vindi * SOME OTHER PRODUCT") == :unknown
      assert resolved_id("CLICK SIGNS COMUNICACAO") == :unknown
      assert resolved_id("CLICKSEND.COM") == :unknown
    end
  end

  # ---------------------------------------------------------------------------------------------
  # Names the descriptor glues together
  # ---------------------------------------------------------------------------------------------

  describe "Hostinger with the descriptor cut at a fixed width" do
    test "the glued spellings resolve" do
      for description <- [
            "DM * hostingercom",
            "DM * hostingercomb",
            "DM * hostingercombr",
            "DL * hostingercomb",
            "DL * HOSTINGERCOMBR",
            "hostingercombr 123",
            "WWW.HOSTINGER.COM",
            "www hostinger com 12",
            "hostinger.com"
          ] do
        assert resolved_id(description) == "hostinger", description
      end
    end

    test "other glued tails and look-alikes do not" do
      for description <- [
            "DM * hostingercomxx",
            "DM * hostingercombrx",
            "DM * hostingerx",
            "MY HOSTINGERCOMB",
            "SUPERHOSTINGER",
            "WWW.HOSTINGERX.COM",
            "WWW.HOSTINGER.NET"
          ] do
        assert resolved_id(description) == :unknown, description
      end
    end
  end

  describe "Heroku's billing domain" do
    test "resolves to Heroku" do
      assert resolved_id("WWW.HEROKUCHARGE.COM") == "heroku"
      assert resolved_id("www herokucharge com 12") == "heroku"
      assert resolved_id("HEROKU * SYNTHETIC-000000001") == "heroku"
    end

    test "look-alikes do not" do
      for description <- [
            "WWW.HEROKUCHARGEX.COM",
            "HEROKUCHARGE",
            "WWW.HEROKUCHARGE.NET",
            "SOME WWW.HEROKUCHARGE.COM"
          ] do
        assert resolved_id(description) == :unknown, description
      end
    end
  end

  # ---------------------------------------------------------------------------------------------
  # A processor that is also a merchant: the vendor behind it is not the processor
  # ---------------------------------------------------------------------------------------------

  describe "Paddle" do
    test "only the processor's own charge resolves to Paddle" do
      for description <- [
            "PADDLE",
            "paddle",
            "PADDLE.NET",
            "PADDLE.NET 123",
            "PADDLE.NET * PADDLE.NET",
            "Paddle.net * Paddle.net 0042"
          ] do
        assert resolved_id(description) == "paddle", description
      end
    end

    test "a charge by a vendor that uses Paddle is not Paddle" do
      for description <- [
            "PADDLE.NET * SOME VENDOR",
            "PADDLE.NET * ANOTHER VENDOR 2",
            "PADDLE.NET * SYNTHETIC CLOUD1",
            "PADDLE * SOME VENDOR",
            "PADDLE.NET * PADDLE.NET EXTRA",
            "PADDLE.NET * PADDLE"
          ] do
        assert resolved_id(description) == :unknown, description
      end
    end

    test "the vendor behind Paddle is never mistaken for another merchant either" do
      assert resolved_id("PADDLE.NET * GITHUB") == :unknown
      assert resolved_id("PADDLE.NET * ADOBE") == :unknown
    end
  end

  # ---------------------------------------------------------------------------------------------
  # FACEBK: one rule, the first token
  # ---------------------------------------------------------------------------------------------

  describe "FACEBK * <anything>" do
    test "every code, hold and suffix shape resolves to Facebook with its icon" do
      for description <- [
            "FACEBK * ADS",
            "FACEBK * AB12CD34EF",
            "FACEBK * TEMP HOLD ZZZZ",
            "FACEBK * XX00AWS000",
            "FACEBK * 1234567890",
            "FACEBK * A",
            "facebk*ab12cd34ef",
            "FACEBK *AB12CD34EF",
            "DL * FACEBK * AB12CD34EF",
            "FACEBOOK ADS 123"
          ] do
        assert resolved_id(description) == "facebook", description
        assert icon(description) == svg("facebook"), description
      end
    end

    test "the code never decides the merchant, even when it contains another merchant's name" do
      for code <- ["AWS", "AWS4", "XX00AWS000", "GOOGLE", "ADOBE12", "UBER", "OPENAI"] do
        assert resolved_id("FACEBK * " <> code) == "facebook", code
      end
    end
  end
end
