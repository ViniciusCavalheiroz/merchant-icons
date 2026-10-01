defmodule Iconify.Icons do
  @moduledoc false

  # Compile-time loading and validation of the SVG icons shipped in `priv/icons`.
  #
  #     Icons.embed!(definitions, dir)
  #
  # A merchant definition may reference an icon with `icon: "slug"`, where the slug is the name
  # of `<dir>/<slug>.svg`. `embed!/2` replaces the slug with the SVG markup, so the public
  # `Merchant.icon` holds the markup itself. A definition without a reference gets `icon: nil`.
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

  alias Iconify.Index

  @type reason ::
          :empty
          | :invalid_utf8
          | :not_svg
          | :missing_view_box
          | :script
          | :foreign_object
          | :javascript_uri
          | :entity
          | :event_handler
          | :external_reference

  # Fragments that must not appear anywhere (compared in lowercase).
  @forbidden_fragments [
    {"<script", :script},
    {"<foreignobject", :foreign_object},
    {"javascript:", :javascript_uri},
    {"<!entity", :entity},
    {"attributename=\"on", :event_handler},
    {"attributename='on", :event_handler}
  ]

  # An attribute name starting with `on` can only follow whitespace, a quote or a slash.
  @event_attribute_starts [" on", "\ton", "\non", "\ron", "\"on", "'on", "/on"]

  # The only URLs allowed to appear in an SVG: its XML namespaces.
  @namespaces ["http://www.w3.org/2000/svg", "http://www.w3.org/1999/xlink"]

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
  directory is not referenced by any merchant. Messages only mention slugs, ids and reasons,
  never the content of a file.
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
    |> ensure_utf8()
    |> ensure_not_empty()
    |> ensure_svg_root()
    |> ensure_view_box()
    |> ensure_safe()
  end

  # embed

  defp embed_icon!(%{icon: slug} = definition, dir) when is_binary(slug) do
    %{definition | icon: read_svg!(definition, slug, dir)}
  end

  defp embed_icon!(definition, _dir), do: Map.put(definition, :icon, nil)

  defp read_svg!(definition, slug, dir) do
    where = "icon #{inspect(slug)} of merchant #{inspect(Map.get(definition, :id))}"

    ensure!(slug?(slug), "#{where} is not a valid slug")

    case File.read(Path.join(dir, slug <> ".svg")) do
      {:ok, content} ->
        validated!(content, where)

      {:error, :enoent} ->
        raise ArgumentError, "#{where} has no file #{slug}.svg"

      {:error, reason} ->
        raise ArgumentError, "#{where} could not be read (#{reason})"
    end
  end

  defp validated!(content, where) do
    case validate(content) do
      {:ok, svg} ->
         svg

      {:error, reason} ->
        raise ArgumentError, "#{where} is invalid (#{reason})"
    end
  end

  defp reject_unreferenced_files!(definitions, dir) do
    referenced = for %{icon: slug} when is_binary(slug) <- definitions, into: MapSet.new(), do: slug

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

  # lowercase ASCII letters, digits and underscores only, so a slug cannot leave the directory
  defp slug?(slug) do
    slug != "" and slug |> :binary.bin_to_list() |> Enum.all?(&(&1 in ?a..?z or &1 in ?0..?9 or &1 == ?_))
  end

  defp ensure!(true, _message), do: :ok
  defp ensure!(false, message), do: raise(ArgumentError, message)

  # validate

  # First step: receives the raw content and starts the pipeline.
  defp ensure_utf8(content) do
    case String.valid?(content) do
      true ->
        {:ok, content}

      false ->
        {:error, :invalid_utf8}
    end
  end

  defp ensure_not_empty({:error, _reason} = error), do: error

  defp ensure_not_empty({:ok, content} = ok) do
    case String.trim(content) do
      "" ->
        {:error, :empty}

      _markup -> ok
    end
  end

  # The root tag must be `<svg` itself: no XML prolog, doctype or comment before it.
  defp ensure_svg_root({:error, _reason} = error), do: error

  defp ensure_svg_root({:ok, content} = ok) do
    case String.trim_leading(content) do
      <<"<svg", next, _rest::binary>> when next in [?\s, ?\t, ?\n, ?\r, ?>, ?/] -> ok
      
      _other -> {:error, :not_svg}
    end
  end

  # `viewBox` is case sensitive in SVG and is what lets the icon scale with CSS.
  defp ensure_view_box({:error, _reason} = error), do: error

  defp ensure_view_box({:ok, content} = ok) do
    [root_tag | _rest] = :binary.split(content, ">")

    case String.contains?(root_tag, ["viewBox=", "viewBox ="]) do
      true -> ok
      false -> {:error, :missing_view_box}
    end
  end

  defp ensure_safe({:error, _reason} = error), do: error

  defp ensure_safe({:ok, content} = ok) do
    lowered = String.downcase(content)

    checks = [&forbidden_fragment/1, &event_handler/1, &external_reference/1]

    case Enum.find_value(checks, & &1.(lowered)) do
      nil -> ok
      reason -> {:error, reason}
    end
  end

  defp forbidden_fragment(lowered) do
    Enum.find_value(@forbidden_fragments, &fragment_reason(&1, lowered))
  end

  defp fragment_reason({fragment, reason}, lowered) do
    case String.contains?(lowered, fragment) do
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

  # `on` followed by at least one letter and then `=` is an event handler attribute.
  defp attribute_assignment?(<<letter, rest::binary>>) when letter in ?a..?z do
    attribute_name_rest?(rest)
  end

  defp attribute_assignment?(_rest), do: false

  defp attribute_name_rest?(<<letter, rest::binary>>) when letter in ?a..?z do
    attribute_name_rest?(rest)
  end

  defp attribute_name_rest?(rest) do
    rest
    |> String.trim_leading()
    |> String.starts_with?("=")
  end

  defp external_reference(lowered) do
    without_namespaces = Enum.reduce(@namespaces, lowered, &String.replace(&2, &1, ""))

    case String.contains?(without_namespaces, ["http:", "https:"]) do
      true -> :external_reference
      false -> nil
    end
  end
end
