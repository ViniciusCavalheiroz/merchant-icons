defmodule MerchantIcons.IconRenderingTest do
  use ExUnit.Case, async: true

  require Record

  alias MerchantIcons.Merchant

  # End-to-end check of the icon pipeline, consuming only the public API:
  #
  #     MerchantIcons.resolve/1 -> Merchant.icon -> HTML page -> renderable SVG
  #
  # There is no browser here. The icon is placed inside a minimal XHTML page and parsed with
  # :xmerl, the XML parser that ships with OTP (not a Hex dependency). A well-formed page with
  # exactly one <svg> element inside <body> is what an HTML parser needs to render the icon
  # inline. The icons come from priv/icons: nothing in this file is a stand-in for them.

  # Mix removes from the code path the OTP applications that the project does not declare, and
  # :xmerl is only used by this test. This puts it back for the test run, without declaring it
  # in mix.exs (it is not a dependency of the library).
  Mix.ensure_application!(:xmerl)

  @xml_hrl "xmerl/include/xmerl.hrl"
  Record.defrecordp(:xml_element, :xmlElement, Record.extract(:xmlElement, from_lib: @xml_hrl))

  Record.defrecordp(
    :xml_attribute,
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: @xml_hrl)
  )

  @icons_dir Path.expand("../../priv/icons", __DIR__)

  # {description, merchant id, icon file in priv/icons}
  @merchants [
    {"Google", "google", "google"},
    {"Adobe", "adobe", "adobe"},
    {"OpenAI", "openai", "openai"},
    {"Spotify", "spotify", "spotify"},
    {"OpenRouter", "openrouter", "openrouter_light"}
  ]

  @forbidden_elements [:script, :iframe, :object, :embed, :foreignObject]
  @forbidden_markup ["<script", "<iframe", "<object", "<embed", "<foreignobject"]
  @namespaces [
    "http://www.w3.org/1999/xhtml",
    "http://www.w3.org/2000/svg",
    "http://www.w3.org/1999/xlink"
  ]

  for {description, id, file} <- @merchants do
    describe "#{id}" do
      @description description
      @id id
      @icon_file file

      test "resolves to the packaged SVG" do
        assert {:ok, %Merchant{id: id, icon: svg}} = MerchantIcons.resolve(@description)

        assert id == @id
        assert is_binary(svg)
        assert svg == File.read!(Path.join(@icons_dir, @icon_file <> ".svg"))
      end

      test "is a single, well-formed, closed <svg> with a viewBox" do
        {:ok, %Merchant{icon: svg}} = MerchantIcons.resolve(@description)

        root = parse!(svg)

        assert xml_element(root, :name) == :svg
        assert String.ends_with?(String.trim_trailing(svg), "</svg>")

        assert {:viewBox, view_box} = List.keyfind(attributes(root), :viewBox, 0)
        assert [_x, _y, width, height] = view_box |> split_view_box() |> Enum.map(&number!/1)
        assert width > 0 and height > 0
      end

      test "can be inserted as markup in an HTML page" do
        {:ok, %Merchant{icon: svg}} = MerchantIcons.resolve(@description)

        page = html_page(svg)
        page_root = parse!(page)
        [body] = find_all(page_root, :body)

        # The icon is exactly one <svg> in the whole page, and a direct child of <body>.
        assert page |> String.downcase() |> :binary.matches("<svg") |> length() == 1
        assert page |> String.downcase() |> :binary.matches("</svg>") |> length() == 1
        assert page_root |> elements() |> Enum.count(&(&1 == :svg)) == 1
        assert body |> xml_element(:content) |> Enum.count(&svg_element?/1) == 1
      end

      test "has no active content" do
        {:ok, %Merchant{icon: svg}} = MerchantIcons.resolve(@description)

        page = html_page(svg)
        page_root = parse!(page)
        names = elements(page_root)

        for forbidden <- @forbidden_elements do
          refute forbidden in names, "found <#{forbidden}>"
        end

        for fragment <- @forbidden_markup do
          refute String.contains?(String.downcase(page), fragment), "found #{fragment}"
        end

        event_handlers =
          for {name, _value} <- all_attributes(page_root),
              name |> Atom.to_string() |> String.starts_with?("on"),
              do: name

        assert event_handlers == []
      end

      test "does not reference anything outside the document" do
        {:ok, %Merchant{icon: svg}} = MerchantIcons.resolve(@description)

        values =
          for {name, value} <- all_attributes(parse!(html_page(svg))),
              not namespace_declaration?(name, value),
              do: {name, value}

        for {name, value} <- values do
          refute String.contains?(value, ["http:", "https:", "//", "javascript:", "data:"]),
                 "#{name} points outside the document"
        end

        for {name, value} <- values, name in [:href, :"xlink:href"] do
          assert String.starts_with?(value, "#"), "#{name} is not a local reference"
        end
      end
    end
  end

  # XHTML is the XML serialization of HTML: the same page an HTML parser would build, but one
  # that :xmerl can check for well-formedness.
  defp html_page(svg) do
    ~s|<html xmlns="http://www.w3.org/1999/xhtml"><head><meta charset="utf-8"/>| <>
      ~s|<title>Icon</title></head><body>#{svg}</body></html>|
  end

  defp parse!(markup) do
    {root, rest} = :xmerl_scan.string(String.to_charlist(markup), quiet: true)

    assert rest |> List.to_string() |> String.trim() == "", "content after the root element"

    root
  catch
    :exit, reason -> flunk("markup is not well-formed XML: #{inspect(reason)}")
  end

  defp elements(xml_element(name: name, content: content)) do
    [name | Enum.flat_map(content, &elements/1)]
  end

  defp elements(_other), do: []

  defp find_all(xml_element(name: name, content: content) = element, target) do
    found = Enum.flat_map(content, &find_all(&1, target))

    case name == target do
      true -> [element | found]
      false -> found
    end
  end

  defp find_all(_other, _target), do: []

  defp svg_element?(node), do: match?(xml_element(name: :svg), node)

  defp attributes(xml_element(attributes: attributes)) do
    for xml_attribute(name: name, value: value) <- attributes do
      {name, List.to_string(value)}
    end
  end

  defp all_attributes(xml_element(content: content) = element) do
    attributes(element) ++ Enum.flat_map(content, &all_attributes/1)
  end

  defp all_attributes(_other), do: []

  defp namespace_declaration?(name, value) do
    name in [:xmlns, :"xmlns:xlink"] and value in @namespaces
  end

  defp split_view_box(view_box), do: String.split(view_box, [" ", ","], trim: true)

  defp number!(text) do
    case Float.parse(text) do
      {number, ""} -> number
      _other -> flunk("viewBox has a value that is not a number: #{inspect(text)}")
    end
  end
end
