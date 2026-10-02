# mix run dev/merchant_icons_preview.exs
#
# Development tool: writes tmp/merchant_icons_preview.html, a page that shows every merchant that
# has an icon, rendered by the real MerchantIcons.Components.merchant_icon/1, to judge visually how
# each logo fills its container. Open the file in a browser. It does not run in production, is not
# part of the Hex package, and changes nothing in the library.
#
# The merchants are enumerated from the dataset and then resolved through MerchantIcons.resolve/1,
# so every icon on the page is the one the application gets. Nothing is copied or scaled here.
#
# The controls are plain CSS (radio inputs), without JavaScript.

import Phoenix.Component
import Phoenix.LiveViewTest
import MerchantIcons.Components

alias MerchantIcons.Merchant

out = Path.join(File.cwd!(), "tmp/merchant_icons_preview.html")

merchants =
  for %{id: id, icon: icon_name, aliases: [{alias_text, _kind} | _rest]} <-
        MerchantIcons.Data.Merchants.all(),
      is_binary(icon_name) do
    # The dataset only holds the icon file name; resolving gives the struct with the real markup.
    {:ok, %Merchant{id: ^id, icon: markup} = merchant} = MerchantIcons.resolve(alias_text)
    true = is_binary(markup)
    merchant
  end
  |> Enum.sort_by(&String.downcase(&1.name))

sizes = [24, 32, 40, 48, 64]

defmodule Preview do
  use Phoenix.Component
  import MerchantIcons.Components

  attr(:merchants, :list, required: true)
  attr(:sizes, :list, required: true)

  def page(assigns) do
    ~H"""
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Merchant Icons Preview</title>
        <style>
          :root { --bg: #f4f5f7; --card: #ffffff; --line: #d9dce1; --text: #1f2430; --muted: #6b7280; }
          * { box-sizing: border-box; }
          body { margin: 0; padding: 24px 16px 64px; background: var(--bg); color: var(--text);
                 font: 14px/1.4 system-ui, -apple-system, "Segoe UI", sans-serif; }
          main { max-width: 1280px; margin: 0 auto; }
          h1 { font-size: 24px; margin: 0 0 4px; }
          h2 { font-size: 18px; margin: 40px 0 4px; }
          .count { color: var(--muted); margin: 0 0 16px; }
          .hint { color: var(--muted); margin: 0 0 16px; font-size: 13px; max-width: 70ch; }
          .controls { display: flex; flex-wrap: wrap; gap: 24px; margin: 0 0 20px; padding: 12px 16px;
                      background: var(--card); border: 1px solid var(--line); border-radius: 8px; }
          .controls fieldset { border: 0; margin: 0; padding: 0; }
          .controls legend { font-weight: 600; margin-bottom: 4px; padding: 0; }
          .controls label { margin-right: 12px; white-space: nowrap; cursor: pointer; }
          .ctl { position: absolute; opacity: 0; pointer-events: none; }
          .grid { display: grid; gap: 16px; grid-template-columns: repeat(auto-fill, minmax(340px, 1fr)); }
          .card { background: var(--card); border: 1px solid var(--line); border-radius: 10px;
                  padding: 14px; min-height: 280px; display: flex; flex-direction: column; }
          .card h3 { margin: 0; font-size: 15px; }
          .card .id { color: var(--muted); font-family: ui-monospace, Menlo, monospace; font-size: 12px; margin-bottom: 10px; }
          .sizes { display: flex; flex-wrap: wrap; gap: 0; margin-top: auto; }
          .cell { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 8px 12px;
                  border-left: 1px solid var(--line); min-width: 78px; }
          .cell:first-child { border-left: 0; }
          .cell .tag { font-size: 11px; color: var(--muted); font-family: ui-monospace, Menlo, monospace; }
          .stage { display: flex; align-items: center; justify-content: center; min-height: 100px; }
          .full { width: 96px; height: 96px; border: 1px dashed #9aa1ad; display: flex; }
          .full img { width: 100%; height: 100%; object-fit: contain; display: block; }

          /* background choice */
          .stage, .dens-cell, .full { background: #ffffff; }
          #bg-checker:checked ~ main .stage, #bg-checker:checked ~ main .dens-cell, #bg-checker:checked ~ main .full {
            background: repeating-conic-gradient(#e6e8ec 0% 25%, #ffffff 0% 50%) 50% / 16px 16px; }
          #bg-dark:checked ~ main .stage, #bg-dark:checked ~ main .dens-cell, #bg-dark:checked ~ main .full { background: #20242c; }

          /* the size picked in the control: only that column is shown */
          .pick { display: none; }
          #sz-24:checked ~ main .pick-24, #sz-32:checked ~ main .pick-32, #sz-40:checked ~ main .pick-40,
          #sz-48:checked ~ main .pick-48, #sz-64:checked ~ main .pick-64 { display: flex; }

          .density { display: grid; gap: 12px; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); }
          .dens { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 10px;
                  display: flex; flex-direction: column; align-items: center; gap: 8px; }
          .dens .row { display: flex; gap: 12px; align-items: center; }
          .dens .name { font-size: 12px; text-align: center; min-height: 2.8em; }
          .dens .name span { display: block; color: var(--muted); font-family: ui-monospace, Menlo, monospace; font-size: 11px; }
          .dens-cell { width: 32px; height: 32px; border: 1px solid #8b93a1; display: flex; flex: none; }
          .dens-cell img { width: 32px; height: 32px; object-fit: contain; display: block; }
          .dens-cell.component { border-color: transparent; }
          .dens .cap { font-size: 10px; color: var(--muted); text-align: center; }
        </style>
      </head>
      <body>
        <input class="ctl" type="radio" name="sz" id="sz-24" />
        <input class="ctl" type="radio" name="sz" id="sz-32" checked />
        <input class="ctl" type="radio" name="sz" id="sz-40" />
        <input class="ctl" type="radio" name="sz" id="sz-48" />
        <input class="ctl" type="radio" name="sz" id="sz-64" />
        <input class="ctl" type="radio" name="bg" id="bg-light" checked />
        <input class="ctl" type="radio" name="bg" id="bg-checker" />
        <input class="ctl" type="radio" name="bg" id="bg-dark" />

        <main>
          <h1>Merchant Icons Preview</h1>
          <p class="count">{length(@merchants)} merchants with icons</p>
          <p class="hint">
            Every icon is rendered by <code>MerchantIcons.Components.merchant_icon/1</code>, the same
            component the application uses. Nothing is scaled or edited here.
          </p>

          <div class="controls">
            <fieldset>
              <legend>Extra size column</legend>
              <label :for={size <- @sizes} for={"sz-#{size}"}>{size}px</label>
            </fieldset>
            <fieldset>
              <legend>Background</legend>
              <label for="bg-light">light</label>
              <label for="bg-checker">checkerboard</label>
              <label for="bg-dark">dark</label>
            </fieldset>
          </div>

          <h2>All merchants with an icon</h2>
          <p class="hint">
            Fixed 32 / 48 / 64 px through <code>merchant_icon/1</code> (the image is inset inside the
            round badge by the component), the icon at 100% of a 96 px square (the bundled SVG drawn
            by <code>icon_data_uri/1</code> with <code>object-fit: contain</code>), and the extra size
            chosen in the control above.
          </p>

          <div class="grid">
            <article :for={merchant <- @merchants} class="card">
              <h3>{merchant.name}</h3>
              <div class="id">{merchant.id}</div>
              <div class="sizes">
                <div :for={size <- [32, 48, 64]} class="cell">
                  <div class="stage"><.merchant_icon merchant={merchant} size={size} /></div>
                  <span class="tag">{size}px</span>
                </div>
                <div class="cell">
                  <div class="stage">
                    <div class="full"><img src={MerchantIcons.icon_data_uri(merchant)} alt={merchant.name} /></div>
                  </div>
                  <span class="tag">100% of 96px</span>
                </div>
                <div :for={size <- @sizes} class={"cell pick pick-#{size}"}>
                  <div class="stage"><.merchant_icon merchant={merchant} size={size} /></div>
                  <span class="tag">{size}px</span>
                </div>
              </div>
            </article>
          </div>

          <h2>Icon density / visual size</h2>
          <p class="hint">
            Each icon in a 32 × 32 px square with a border and <code>object-fit: contain</code>
            (left), next to what <code>merchant_icon/1</code> renders at 32 px (right). Icons that look
            smaller than the others in the same box have more empty space inside their SVG.
          </p>

          <div class="density">
            <div :for={merchant <- @merchants} class="dens">
              <div class="row">
                <div class="dens-cell">
                  <img src={MerchantIcons.icon_data_uri(merchant)} alt={merchant.name} />
                </div>
                <div class="dens-cell component"><.merchant_icon merchant={merchant} size={32} /></div>
              </div>
              <div class="cap">contain 32×32 &nbsp;|&nbsp; component 32</div>
              <div class="name">{merchant.name}<span>{merchant.id}</span></div>
            </div>
          </div>
        </main>
      </body>
    </html>
    """
  end
end

assigns = %{merchants: merchants, sizes: sizes}
html = rendered_to_string(~H"<Preview.page merchants={@merchants} sizes={@sizes} />")

File.mkdir_p!(Path.dirname(out))
File.write!(out, html)

IO.puts("#{length(merchants)} merchants with icons rendered")
IO.puts("wrote #{out} (#{div(byte_size(html), 1024)} KiB)")
IO.puts("open it in a browser, for example: open #{out}")
