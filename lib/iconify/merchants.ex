defmodule Iconify.Merchants do
  @moduledoc false

  # The production merchant dataset: plain data, validated at compile time by
  # `Iconify.Index.build/2`.
  #
  # Alias kinds change the matching surface, so review them carefully:
  #
  #   * `:leading` - the alias must start the description (after a processor prefix, if any).
  #                  Whatever follows is unconstrained. Used for distinctive names.
  #   * `:whole`   - the alias must account for every token left after the processor prefix;
  #                  only digits-only tokens may follow. Used for short or generic names that
  #                  would otherwise match unrelated descriptions.
  #
  # Case, accents and punctuation do not matter when writing an alias. Variants whose suffix is
  # an arbitrary code are not enumerated, and a name glued to such a code is not matched.
  # Aliases that start with a token that is not a processor prefix (for example `www`) are
  # written out in full.
  #
  # Icons: `icon: "slug"` references the file `priv/icons/slug.svg`, which is embedded in the
  # merchant when the library compiles (see `Iconify.Icons`). A reference without a file, an
  # invalid file, or a file that no merchant references stops the compilation. `icon: nil`
  # means the merchant has no icon yet: to add one, put the SVG in `priv/icons` and replace
  # `nil` with its slug. Several merchants may reference the same file.

  @spec all() :: [Iconify.Index.definition()]
  def all do
    [
      %{id: "google", name: "Google", icon: nil, aliases: [{"google", :leading}]},
      %{
        id: "uber",
        name: "Uber",
        icon: nil,
        aliases: [{"uber", :leading}, {"uberrides", :whole}]
      },
      %{id: "adobe", name: "Adobe", icon: nil, aliases: [{"adobe", :leading}]},
      %{id: "taboola", name: "Taboola", icon: nil, aliases: [{"taboola", :leading}]},
      %{id: "openai", name: "OpenAI", icon: nil, aliases: [{"openai", :leading}]},
      %{
        id: "amazon",
        name: "Amazon",
        icon: nil,
        aliases: [{"amazon", :leading}, {"amazonmktplc", :leading}]
      },
      %{
        id: "aws",
        name: "AWS",
        icon: nil,
        aliases: [{"amazon web services", :leading}, {"amazon aws", :leading}]
      },
      %{
        id: "apple",
        name: "Apple",
        icon: nil,
        aliases: [{"apple", :leading}, {"applecombill", :leading}]
      },
      %{
        id: "cloudflare",
        name: "Cloudflare",
        icon: nil,
        aliases: [{"cloudflare", :leading}]
      },
      %{
        id: "facebook",
        name: "Facebook",
        icon: nil,
        aliases: [{"facebk", :leading}, {"facebook", :leading}]
      },
      %{id: "stape", name: "Stape", icon: nil, aliases: [{"stape", :leading}]},
      %{
        id: "twilio",
        name: "Twilio",
        icon: nil,
        aliases: [{"twilio", :leading}, {"sendgrid", :leading}]
      },
      %{
        id: "google_one",
        name: "Google One",
        icon: nil,
        aliases: [{"google one", :leading}]
      },
      %{
        id: "databricks",
        name: "Databricks",
        icon: nil,
        aliases: [{"databricks", :leading}]
      },
      %{id: "manychat", name: "ManyChat", icon: nil, aliases: [{"manychat", :leading}]},
      %{id: "zapsign", name: "ZapSign", icon: nil, aliases: [{"zapsign", :leading}]},
      %{id: "clickup", name: "ClickUp", icon: nil, aliases: [{"clickup", :leading}]},
      %{id: "linkedin", name: "LinkedIn", icon: nil, aliases: [{"linkedin", :leading}]},
      %{
        id: "contabo",
        name: "Contabo",
        icon: nil,
        aliases: [{"contabo", :leading}, {"www contabo com", :leading}]
      },
      %{id: "kwai", name: "Kwai", icon: nil, aliases: [{"kwai", :leading}]},
      %{id: "replit", name: "Replit", icon: nil, aliases: [{"replit", :leading}]},
      %{id: "vercel", name: "Vercel", icon: nil, aliases: [{"vercel", :leading}]},
      %{id: "manus_ai", name: "Manus AI", icon: nil, aliases: [{"manus ai", :leading}]},
      %{
        id: "mercado_livre",
        name: "Mercado Livre",
        icon: nil,
        aliases: [
          {"mercadolivre", :leading},
          {"mercado livre", :leading},
          {"mercado mercadolivre", :leading}
        ]
      },
      %{
        id: "anthropic",
        name: "Anthropic",
        icon: nil,
        aliases: [{"anthropic", :leading}]
      },
      %{id: "github", name: "GitHub", icon: nil, aliases: [{"github", :leading}]},
      %{
        id: "hostinger",
        name: "Hostinger",
        icon: nil,
        aliases: [{"hostinger", :leading}]
      },
      %{
        id: "gamifytech",
        name: "GamifyTech",
        icon: nil,
        aliases: [{"gamifytech", :leading}]
      },
      %{id: "figma", name: "Figma", icon: nil, aliases: [{"figma", :leading}]},
      %{id: "claude", name: "Claude", icon: nil, aliases: [{"claude ai", :leading}]},
      %{
        id: "digitalocean",
        name: "DigitalOcean",
        icon: nil,
        aliases: [{"digitalocean", :leading}]
      },
      %{
        id: "miro",
        name: "Miro",
        icon: nil,
        aliases: [{"miro", :whole}, {"miro com", :leading}]
      },
      %{
        id: "new_relic",
        name: "New Relic",
        icon: nil,
        aliases: [{"new relic", :leading}, {"nri new relic", :leading}]
      },
      %{
        id: "atlassian",
        name: "Atlassian",
        icon: nil,
        aliases: [{"atlassian", :leading}]
      },
      %{
        id: "digiochat",
        name: "DigioChat",
        icon: nil,
        aliases: [{"digiochat", :leading}, {"digochat", :leading}]
      },
      %{id: "hex", name: "Hex", icon: nil, aliases: [{"hex tech", :leading}]},
      %{id: "semrush", name: "Semrush", icon: nil, aliases: [{"semrush", :leading}]},
      %{id: "nuuvem", name: "Nuuvem", icon: nil, aliases: [{"nuuvem", :leading}]},
      %{
        id: "supermetrics",
        name: "Supermetrics",
        icon: nil,
        aliases: [{"supermetrics", :leading}]
      },
      %{
        id: "elevenlabs",
        name: "ElevenLabs",
        icon: nil,
        aliases: [{"elevenlabs", :leading}, {"eleven labs", :leading}]
      },
      %{
        id: "mongodb",
        name: "MongoDB",
        icon: nil,
        aliases: [{"mongodb", :leading}, {"mongodbcloud", :leading}]
      },
      %{id: "slack", name: "Slack", icon: nil, aliases: [{"slack", :leading}]},
      %{
        id: "octuz_ai",
        name: "Octuz AI",
        icon: nil,
        aliases: [{"octuz ai", :leading}, {"ckt octuz ai", :leading}]
      },
      %{
        id: "1password",
        name: "1Password",
        icon: nil,
        aliases: [{"1password", :leading}]
      },
      %{id: "openvpn", name: "OpenVPN", icon: nil, aliases: [{"openvpn", :leading}]},
      %{id: "paddle", name: "Paddle", icon: nil, aliases: [{"paddle", :leading}]},
      %{
        id: "mailgun",
        name: "Mailgun",
        icon: nil,
        aliases: [{"mailgun", :leading}, {"sinch mailgun", :leading}]
      },
      %{id: "timescale", name: "Timescale", icon: nil, aliases: [{"timescale", :leading}]},
      %{id: "teramind", name: "Teramind", icon: nil, aliases: [{"teramind", :leading}]},
      %{id: "adspower", name: "AdsPower", icon: nil, aliases: [{"adspower", :leading}]},
      %{id: "gather", name: "Gather", icon: nil, aliases: [{"gather", :whole}]},
      %{
        id: "xai",
        name: "xAI",
        icon: nil,
        aliases: [{"xai", :leading}, {"grok xai", :leading}]
      },
      %{id: "kalunga", name: "Kalunga", icon: nil, aliases: [{"kalunga", :leading}]},
      %{id: "z_api", name: "Z-API", icon: nil, aliases: [{"z-api", :leading}]},
      %{id: "credithub", name: "Credithub", icon: nil, aliases: [{"credithub", :leading}]},
      %{
        id: "artlist",
        name: "Artlist",
        icon: nil,
        aliases: [{"artlist", :leading}, {"www artlist io", :leading}]
      },
      %{id: "notion", name: "Notion", icon: nil, aliases: [{"notion", :leading}]},
      %{id: "aiven", name: "Aiven", icon: nil, aliases: [{"aiven", :leading}]},
      %{
        id: "hootsuite",
        name: "Hootsuite",
        icon: nil,
        aliases: [{"hootsuite", :leading}]
      },
      %{
        id: "cursor",
        name: "Cursor",
        icon: nil,
        aliases: [{"cursor ai", :leading}, {"cursor", :whole}]
      },
      %{
        id: "magnific",
        name: "Magnific",
        icon: nil,
        aliases: [{"magnific", :leading}, {"mgf magnific", :leading}]
      },
      %{
        id: "klingai",
        name: "KlingAI",
        icon: nil,
        aliases: [{"klingai", :leading}, {"kling ai", :leading}]
      },
      %{
        id: "openrouter",
        name: "OpenRouter",
        icon: nil,
        aliases: [{"openrouter", :leading}]
      },
      %{
        id: "remini",
        name: "Remini",
        icon: nil,
        aliases: [{"remini", :leading}, {"app remini ai", :leading}]
      },
      %{
        id: "sportradar",
        name: "Sportradar",
        icon: nil,
        aliases: [{"sportradar", :leading}]
      },
      %{
        id: "clicksign",
        name: "Clicksign",
        icon: nil,
        aliases: [{"clicksign", :leading}]
      },
      %{id: "zendesk", name: "Zendesk", icon: nil, aliases: [{"zendesk", :leading}]},
      %{
        id: "midjourney",
        name: "Midjourney",
        icon: nil,
        aliases: [{"midjourney", :leading}]
      },
      %{id: "supabase", name: "Supabase", icon: nil, aliases: [{"supabase", :leading}]},
      %{
        id: "panda_video",
        name: "Panda Video",
        icon: nil,
        aliases: [{"panda video", :leading}]
      },
      %{
        id: "pipedrive",
        name: "Pipedrive",
        icon: nil,
        aliases: [{"pipedrive", :leading}]
      },
      %{
        id: "cellxpert",
        name: "Cellxpert",
        icon: nil,
        aliases: [{"cellxpert", :leading}]
      },
      %{
        id: "clickhouse",
        name: "ClickHouse",
        icon: nil,
        aliases: [{"clickhouse", :leading}]
      },
      %{id: "blackbox", name: "Blackbox", icon: nil, aliases: [{"blackbox", :leading}]},
      %{id: "envato", name: "Envato", icon: nil, aliases: [{"envato", :leading}]},
      %{
        id: "jetbrains",
        name: "JetBrains",
        icon: nil,
        aliases: [{"jetbrains", :leading}]
      },
      %{
        id: "hostgator",
        name: "HostGator",
        icon: nil,
        aliases: [{"hostgator", :leading}]
      },
      %{
        id: "microsoft",
        name: "Microsoft",
        icon: nil,
        aliases: [{"microsoft", :leading}]
      },
      %{id: "designi", name: "Designi", icon: nil, aliases: [{"designi", :leading}]},
      %{
        id: "socialblade",
        name: "Social Blade",
        icon: nil,
        aliases: [{"socialblade", :leading}, {"social blade", :leading}]
      },
      %{id: "freepik", name: "Freepik", icon: nil, aliases: [{"freepik", :leading}]},
      %{id: "capcut", name: "CapCut", icon: nil, aliases: [{"capcut", :leading}]},
      %{
        id: "contabilizei",
        name: "Contabilizei",
        icon: nil,
        aliases: [{"contabilizei", :leading}]
      },
      %{id: "apollo", name: "Apollo", icon: nil, aliases: [{"apollo io", :leading}]},
      %{id: "sentry", name: "Sentry", icon: nil, aliases: [{"sentry", :whole}]},
      %{id: "stripo", name: "Stripo", icon: nil, aliases: [{"stripo", :leading}]},
      %{
        id: "appsflyer",
        name: "AppsFlyer",
        icon: nil,
        aliases: [{"appsflyer", :leading}]
      },
      %{id: "strapi", name: "Strapi", icon: nil, aliases: [{"strapi", :leading}]},
      %{id: "starlink", name: "Starlink", icon: nil, aliases: [{"starlink", :leading}]},
      %{
        id: "crypto_com",
        name: "Crypto.com",
        icon: nil,
        aliases: [{"crypto com", :leading}]
      },
      %{id: "airbnb", name: "Airbnb", icon: nil, aliases: [{"airbnb", :leading}]},
      %{id: "metabase", name: "Metabase", icon: nil, aliases: [{"metabase", :leading}]},
      %{id: "mega", name: "Mega", icon: nil, aliases: [{"mega limited", :leading}]},
      %{id: "fly_io", name: "Fly.io", icon: nil, aliases: [{"fly io", :leading}]},
      %{id: "synology", name: "Synology", icon: nil, aliases: [{"synology", :leading}]},
      %{id: "heroku", name: "Heroku", icon: nil, aliases: [{"heroku", :leading}]},
      %{id: "lovable", name: "Lovable", icon: nil, aliases: [{"lovable", :leading}]},
      %{id: "postman", name: "Postman", icon: nil, aliases: [{"postman", :leading}]},
      %{
        id: "runninghub",
        name: "RunningHub",
        icon: nil,
        aliases: [{"runninghub", :leading}]
      },
      %{
        id: "fingerprint",
        name: "Fingerprint",
        icon: nil,
        aliases: [{"fingerprint", :whole}]
      },
      %{
        id: "footystats",
        name: "FootyStats",
        icon: nil,
        aliases: [{"footystats", :leading}]
      },
      %{id: "npm", name: "npm", icon: nil, aliases: [{"npm", :leading}]},
      %{
        id: "ui",
        name: "UI",
        icon: nil,
        aliases: [{"ui", :whole}, {"www ui com", :whole}]
      },
      %{
        id: "readme",
        name: "Readme",
        icon: nil,
        aliases: [{"readme", :whole}, {"readme com", :leading}]
      },
      %{id: "bitly", name: "Bitly", icon: nil, aliases: [{"bitly", :leading}]},
      %{
        id: "squarespace",
        name: "Squarespace",
        icon: nil,
        aliases: [{"squarespace", :leading}]
      },
      %{id: "genspark", name: "Genspark", icon: nil, aliases: [{"genspark", :leading}]},
      %{id: "netlify", name: "Netlify", icon: nil, aliases: [{"netlify", :leading}]},
      %{id: "spotify", name: "Spotify", icon: "spotify", aliases: [{"spotify", :leading}]}
    ]
  end
end
