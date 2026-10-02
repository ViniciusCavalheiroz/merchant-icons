defmodule MerchantIcons.Icons do
  @moduledoc false

  # Compile-time loading and validation of the SVG icons shipped in `priv/icons`.
  #
  #     Icons.embed!(definitions, dir)
  #
  # A merchant definition may reference an icon with `icon: "icon_name"`, where the icon name is
  # the file name of `<dir>/<icon_name>.svg` without the extension. `embed!/2` replaces the icon
  # name with the SVG markup, so the public `Merchant.icon` holds the markup itself. A definition
  # without a reference gets `icon: nil`.
  #
  # This module keeps no state and runs only while the library compiles: the SVGs end up as
  # literals of the module that embeds them. Nothing reads the icons directory at runtime.
  #
  # Consumers are expected to inline the markup into HTML, so a tampered file would be an XSS
  # vector. Validation therefore rejects, at compile time, everything that could execute code
  # or reach the network. It works on the text of the file: there is no XML parser, because
  # parsing untrusted XML is itself a risk, and no regular expressions.
  #
  # The checks are deliberately strict and crude. A file that trips one of them has to be
  # cleaned (for example metadata with external URLs removed) before it can be shipped.
  #
  # Because the text is not parsed, the checks look at a "compact" copy of the file (lowercase,
  # all ASCII whitespace removed). Browsers ignore tabs and newlines inside URLs and decode
  # character references in attribute values, so `java<TAB>script:` or `jav&#97;script:` would
  # slip past a literal comparison. Any `&` is therefore rejected, and no icon needs one.
  #
  # Files are limited in size and must be regular files (no symlinks): the library compiles on
  # the machines of its users, so a tampered file must not make the build read other files or
  # allocate unbounded memory.

  alias MerchantIcons.Matching.Index

  @type reason ::
          :empty
          | :too_large
          | :invalid_utf8
          | :not_svg
          | :trailing_content
          | :missing_view_box
          | :script
          | :foreign_object
          | :embedded_content
          | :javascript_uri
          | :data_uri
          | :doctype
          | :entity
          | :event_handler
          | :external_reference
          | {:disallowed_element, String.t()}
          | :unbalanced_svg

  # Maximum size of an icon file, in bytes. The shipped icons are below 10 KB; the limit only
  # exists so a tampered file cannot inflate the compiled module.
  @max_bytes 100_000

  # Fragments that must not appear anywhere (compared in lowercase, ignoring whitespace).
  @forbidden_fragments [
    {"<script", :script},
    {"<foreignobject", :foreign_object},
    {"<iframe", :embedded_content},
    {"<object", :embedded_content},
    {"<embed", :embedded_content},
    {"javascript:", :javascript_uri},
    {"data:", :data_uri},
    {"<!doctype", :doctype},
    {"<!entity", :entity},
    {"&", :entity},
    {"attributename=\"on", :event_handler},
    {"attributename='on", :event_handler},
    {"attributename=on", :event_handler},
    {"@import", :external_reference}
  ]

  # Elements an icon may contain. This is an allowlist on top of the denylist checks above: any
  # other element, including HTML elements that break out of the SVG when the markup is inlined
  # (`<p>`, `<form>`, `<a>`) and animation or styling elements (`<animate>`, `<set>`, `<style>`),
  # is rejected. Names are case-sensitive, as in SVG. Extend the list only for elements that
  # cannot load resources, run code or navigate.
  @allowed_elements MapSet.new(~w(
    svg g path rect circle ellipse line polyline polygon defs symbol use title desc
    stop linearGradient radialGradient pattern clipPath mask filter
    feGaussianBlur feOffset feBlend feColorMatrix feComposite feFlood feMerge feMergeNode
  ))

  # Longest element name that is read; anything longer cannot be in the allowlist.
  @max_element_name 40

  # An attribute name starting with `on` can only follow whitespace, a quote or a slash.
  # HTML treats form feed as whitespace too.
  @event_attribute_starts [" on", "\ton", "\non", "\ron", "\fon", "\"on", "'on", "/on"]

  # The only URLs allowed to appear in an SVG: its XML namespaces.
  @namespaces ["http://www.w3.org/2000/svg", "http://www.w3.org/1999/xlink"]

  # Anything that can start a request to another origin, or a navigation, once the namespaces
  # are removed. `//` also catches protocol-relative URLs.
  @external_markers ["http:", "https:", "ftp:", "file:", "//"]

  # Attributes and CSS functions that may only point inside the document (`#id`).
  @local_only_references ["href=", "src=", "url("]

  @doc "Maximum size of an icon file, in bytes."
  @spec max_bytes() :: pos_integer()
  def max_bytes, do: @max_bytes

  @doc "Paths of the SVG files in a directory."
  @spec files(Path.t()) :: [Path.t()]
  def files(dir) do
    dir
    |> Path.join("*.svg")
    |> Path.wildcard()
    |> Enum.sort()
  end

  @doc """
  Replaces the icon reference of every definition with the validated SVG markup.

  Raises `ArgumentError` when a referenced file is missing or invalid, or when a file in the
  directory is not referenced by any merchant. Messages only mention icon names, ids and reasons,
  never the content of a file. The one detail they add is the name of a rejected element.
  """
  @spec embed!([Index.definition()], Path.t()) :: [Index.definition()]
  def embed!(definitions, dir) do
    reject_unreferenced_files!(definitions, dir)
    Enum.map(definitions, &embed_icon!(&1, dir))
  end

  @doc "Validates SVG markup. Returns the markup unchanged when it is acceptable."
  @spec validate(binary()) :: {:ok, String.t()} | {:error, reason()}
  def validate(content) do
    content
    |> ensure_size()
    |> ensure_utf8()
    |> ensure_not_empty()
    |> ensure_svg_root()
    |> ensure_svg_end()
    |> ensure_view_box()
    |> ensure_no_active_content()
    |> ensure_allowed_elements()
  end

  # embed

  defp embed_icon!(%{icon: icon_name} = definition, dir) when is_binary(icon_name),
    do: %{definition | icon: read_svg!(definition, icon_name, dir)}

  defp embed_icon!(definition, _dir),
    do: Map.put(definition, :icon, nil)

  defp read_svg!(definition, icon_name, dir) do
    where = "icon #{inspect(icon_name)} of merchant #{inspect(Map.get(definition, :id))}"

    ensure!(valid_icon_name?(icon_name), "#{where} is not a valid icon name")

    path = Path.join(dir, icon_name <> ".svg")

    case File.lstat(path) do
      {:ok, %File.Stat{type: :regular, size: size}} when size <= @max_bytes ->
        read_validated!(path, where)

      {:ok, %File.Stat{type: :regular}} ->
        raise ArgumentError, "#{where} is invalid (too_large)"

      {:ok, %File.Stat{}} ->
        raise ArgumentError, "#{where} must be a regular file, not a link or directory"

      {:error, :enoent} ->
        raise ArgumentError, "#{where} has no file #{icon_name}.svg"

      {:error, reason} ->
        raise ArgumentError, "#{where} could not be read (#{reason})"
    end
  end

  defp read_validated!(path, where) do
    case File.read(path) do
      {:ok, content} -> validated!(content, where)
      {:error, reason} -> raise ArgumentError, "#{where} could not be read (#{reason})"
    end
  end

  defp validated!(content, where) do
    case validate(content) do
      {:ok, svg} -> svg
      {:error, reason} -> raise ArgumentError, "#{where} is invalid (#{describe_reason(reason)})"
    end
  end

  # A rejected element is named so a contributor can see what to change in the file.
  defp describe_reason({reason, detail}), do: "#{reason}: #{inspect(detail)}"
  defp describe_reason(reason), do: to_string(reason)

  defp reject_unreferenced_files!(definitions, dir) do
    referenced =
      for %{icon: icon_name} when is_binary(icon_name) <- definitions,
          into: MapSet.new(),
          do: icon_name

    unreferenced =
      dir
      |> files()
      |> Enum.map(&Path.basename(&1, ".svg"))
      |> Enum.reject(&MapSet.member?(referenced, &1))

    ensure!(
      unreferenced == [],
      "icon files without a merchant: #{Enum.join(unreferenced, ", ")}"
    )
  end

  # Lowercase ASCII letters, digits and underscores only, so an icon name cannot leave the
  # icons directory.
  defp valid_icon_name?(""), do: false

  defp valid_icon_name?(icon_name),
    do:
      icon_name
      |> :binary.bin_to_list()
      |> Enum.all?(&(&1 in ?a..?z or &1 in ?0..?9 or &1 == ?_))

  defp ensure!(true, _message), do: :ok
  defp ensure!(false, message), do: raise(ArgumentError, message)

  # validate

  # The size check is O(1) and runs before anything scans the content.
  defp ensure_size(content) when byte_size(content) > @max_bytes, do: {:error, :too_large}
  defp ensure_size(content), do: {:ok, content}

  defp ensure_utf8({:error, _} = error), do: error

  defp ensure_utf8({:ok, content}) do
    case String.valid?(content) do
      true -> {:ok, content}
      false -> {:error, :invalid_utf8}
    end
  end

  defp ensure_not_empty({:error, _} = error), do: error

  defp ensure_not_empty({:ok, content} = ok) do
    case String.trim(content) do
      "" -> {:error, :empty}
      _ -> ok
    end
  end

  defp ensure_svg_root({:error, _} = error), do: error

  defp ensure_svg_root({:ok, content} = ok) do
    case String.trim_leading(content) do
      <<"<svg", next, _rest::binary>> when next in [?\s, ?\t, ?\n, ?\r, ?>, ?/] -> ok
      _ -> {:error, :not_svg}
    end
  end

  # Nothing may follow the closing tag: HTML elements placed after `</svg>` would be outside
  # the SVG when the markup is inlined.
  defp ensure_svg_end({:error, _} = error), do: error

  defp ensure_svg_end({:ok, content} = ok) do
    case content |> String.trim_trailing() |> String.ends_with?("</svg>") do
      true -> ok
      false -> {:error, :trailing_content}
    end
  end

  defp ensure_view_box({:error, _} = error), do: error

  defp ensure_view_box({:ok, content} = ok) do
    [root_tag | _rest] = :binary.split(content, ">")

    case String.contains?(root_tag, ["viewBox=", "viewBox ="]) do
      true -> ok
      false -> {:error, :missing_view_box}
    end
  end

  # Rejects content that could execute code or reach the network.
  defp ensure_no_active_content({:error, _} = error), do: error

  defp ensure_no_active_content({:ok, content} = ok) do
    lowered = String.downcase(content)
    compact = remove_whitespace(lowered)

    checks = [
      fn _lowered, compact -> forbidden_fragment(compact) end,
      fn lowered, _compact -> event_handler(lowered) end,
      fn _lowered, compact -> external_reference(compact) end,
      fn _lowered, compact -> non_local_reference(compact) end
    ]

    case Enum.find_value(checks, & &1.(lowered, compact)) do
      nil -> ok
      reason -> {:error, reason}
    end
  end

  # Every `<` must start an allowed element (or its closing tag). The first `<svg` must be
  # closed by the last tag of the file: anything between roots, after the root, or unbalanced is
  # rejected. A `<` that does not start an allowed name (`<!--`, `<?`, `<![CDATA[`, `< `) is
  # rejected too, so the scan never has to guess how a browser would read it.
  defp ensure_allowed_elements({:error, _} = error), do: error

  defp ensure_allowed_elements({:ok, content} = ok) do
    tags =
      for {position, _length} <- :binary.matches(content, "<"),
          do: tag_at(content, position + 1)

    case check_tags(tags) do
      nil -> ok
      reason -> {:error, reason}
    end
  end

  defp tag_at(content, start) do
    window = binary_part(content, start, min(@max_element_name, byte_size(content) - start))

    case window do
      <<"/", name::binary>> -> {:close, element_name(name)}
      name -> {:open, element_name(name)}
    end
  end

  defp element_name(window) do
    case :binary.match(window, [" ", "\t", "\n", "\r", "\f", "/", ">"]) do
      {position, _length} -> binary_part(window, 0, position)
      :nomatch -> window
    end
  end

  # State: svg nesting depth and whether the root has been closed. A rejected element reports
  # its name (read from a window of @max_element_name bytes, so a file cannot inflate the reason).
  defp check_tags(tags) do
    result =
      Enum.reduce_while(tags, {0, false}, fn {kind, name}, {depth, closed?} ->
        cond do
          not MapSet.member?(@allowed_elements, name) ->
            {:halt, {:error, {:disallowed_element, name}}}

          closed? ->
            {:halt, {:error, :trailing_content}}

          name != "svg" ->
            {:cont, {depth, false}}

          kind == :open ->
            {:cont, {depth + 1, false}}

          depth == 1 ->
            {:cont, {0, true}}

          depth > 1 ->
            {:cont, {depth - 1, false}}

          true ->
            {:halt, {:error, :trailing_content}}
        end
      end)

    case result do
      {:error, reason} -> reason
      {_depth, true} -> nil
      {_depth, false} -> :unbalanced_svg
    end
  end

  # ASCII whitespace that HTML and URL parsers ignore or treat as separators.
  defp remove_whitespace(text) do
    String.replace(text, [" ", "\t", "\n", "\r", "\f"], "")
  end

  # active content checks

  defp forbidden_fragment(compact) do
    Enum.find_value(@forbidden_fragments, &fragment_reason(&1, compact))
  end

  defp fragment_reason({fragment, reason}, compact) do
    case String.contains?(compact, fragment) do
      true -> reason
      false -> nil
    end
  end

  defp event_handler(lowered) do
    case event_handler?(lowered) do
      true -> :event_handler
      false -> nil
    end
  end

  defp event_handler?(lowered) do
    lowered
    |> :binary.matches(@event_attribute_starts)
    |> Enum.any?(&assignment_after?(&1, lowered))
  end

  defp assignment_after?({position, length}, lowered) do
    rest_start = position + length
    attribute_assignment?(binary_part(lowered, rest_start, byte_size(lowered) - rest_start))
  end

  defp attribute_assignment?(<<letter, rest::binary>>) when letter in ?a..?z,
    do: attribute_name_rest?(rest)

  defp attribute_assignment?(_rest), do: false

  defp attribute_name_rest?(<<letter, rest::binary>>) when letter in ?a..?z,
    do: attribute_name_rest?(rest)

  defp attribute_name_rest?(rest),
    do: rest |> String.trim_leading() |> String.starts_with?("=")

  defp external_reference(compact) do
    without_namespaces = Enum.reduce(@namespaces, compact, &String.replace(&2, &1, ""))

    case String.contains?(without_namespaces, @external_markers) do
      true -> :external_reference
      false -> nil
    end
  end

  # `href=`, `src=` and `url(` may only reference something inside the document (`#id`), with
  # or without quotes. Relative paths would make the consumer's browser request files from its
  # own origin.
  defp non_local_reference(compact) do
    local_only? =
      @local_only_references
      |> Enum.flat_map(&:binary.matches(compact, &1))
      |> Enum.all?(&local_reference?(&1, compact))

    case local_only? do
      true -> nil
      false -> :external_reference
    end
  end

  defp local_reference?({position, length}, compact) do
    rest_start = position + length
    rest = binary_part(compact, rest_start, byte_size(compact) - rest_start)

    case rest do
      <<quote, "#", _rest::binary>> when quote in [?", ?'] -> true
      <<"#", _rest::binary>> -> true
      _other -> false
    end
  end
end
