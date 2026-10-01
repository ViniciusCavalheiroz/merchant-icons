defmodule MerchantIcons.Merchant do
  @moduledoc """
  A merchant known to MerchantIcons.

  The struct only ever contains data from the merchant dataset. It never contains any part of
  the transaction description that was resolved.

  ## Fields

    * `:id` - stable identifier in `snake_case` ASCII (for example `"google"`). It is unique in
      the dataset and is never reused or renamed once published. Use it to identify the
      merchant, for example to store it.
    * `:name` - display name (for example `"Google"`).
    * `:icon` - the complete SVG markup of the merchant logo, or `nil` when the merchant has no
      icon. It is trusted, static content shipped with the library: nothing is fetched and
      nothing depends on the network or the file system at runtime. Render it with
      `merchant.icon`; there is no URL, path or icon name to resolve.

  The icon is left out of `inspect/1` because of its size. When serializing a merchant, pick
  the fields you need instead of the whole struct.

  New fields may be added in minor versions. Match on the keys you need (`%MerchantIcons.Merchant{id:
  id}`) instead of assuming the complete set of fields.
  """

  @derive {Inspect, except: [:icon]}
  @enforce_keys [:id, :name]
  defstruct [:id, :name, icon: nil]

  @typedoc "A merchant known to MerchantIcons. `icon` is SVG markup, or `nil` without an icon."
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          icon: String.t() | nil
        }
end
