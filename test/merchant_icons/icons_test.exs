defmodule MerchantIcons.IconsTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Icons

  # The markup below is the smallest text that satisfies or violates each rule. It is not a logo
  # and is never written to priv/icons.
  @minimal ~s|<svg viewBox="0 0 1 1"></svg>|

  defp invalid(content), do: Icons.validate(content)

  defp with_view_box(inner), do: ~s|<svg viewBox="0 0 1 1">#{inner}</svg>|

  defp definition(overrides) do
    Map.merge(%{id: "ok", name: "Ok", aliases: [{"ok", :leading}]}, overrides)
  end

  defp message(fun) do
    assert_raise(ArgumentError, fun).message
  end

  describe "validate/1 accepted markup" do
    test "returns the markup unchanged" do
      assert Icons.validate(@minimal) == {:ok, @minimal}
    end

    test "tolerates surrounding whitespace" do
      markup = "\n  " <> @minimal <> "\n"

      assert Icons.validate(markup) == {:ok, markup}
    end

    test "accepts the svg and xlink namespaces" do
      markup =
        ~s|<svg xmlns="http://www.w3.org/2000/svg" | <>
          ~s|xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1 1"></svg>|

      assert Icons.validate(markup) == {:ok, markup}
    end

    test "does not mistake ordinary attribute values for event handlers" do
      markup = with_view_box(~s|<path class="one" fill="none" id="online"/>|)

      assert Icons.validate(markup) == {:ok, markup}
    end
  end

  describe "validate/1 structure" do
    test "rejects empty files" do
      assert invalid("") == {:error, :empty}
      assert invalid("  \n\t ") == {:error, :empty}
    end

    test "rejects invalid UTF-8" do
      assert invalid(<<0xFF, 0xFE>>) == {:error, :invalid_utf8}
      assert invalid(@minimal <> <<0xFF>>) == {:error, :invalid_utf8}
    end

    test "rejects content that does not start with <svg" do
      assert invalid("hello") == {:error, :not_svg}
      assert invalid(~s|<?xml version="1.0"?>| <> @minimal) == {:error, :not_svg}
      assert invalid("<!-- note -->" <> @minimal) == {:error, :not_svg}
      assert invalid(~s|<svgx viewBox="0 0 1 1"></svgx>|) == {:error, :not_svg}
      assert invalid(~s|<SVG viewBox="0 0 1 1"></SVG>|) == {:error, :not_svg}
    end

    test "requires viewBox on the root tag, with the exact casing" do
      assert invalid("<svg></svg>") == {:error, :missing_view_box}
      assert invalid(~s|<svg viewbox="0 0 1 1"></svg>|) == {:error, :missing_view_box}

      assert invalid(~s|<svg width="1"><g viewBox="0 0 1 1"/></svg>|) ==
               {:error, :missing_view_box}
    end
  end

  describe "validate/1 forbidden content" do
    test "rejects scripts, whatever the casing" do
      assert invalid(with_view_box("<script>x()</script>")) == {:error, :script}
      assert invalid(with_view_box("<SCRIPT>x()</SCRIPT>")) == {:error, :script}
    end

    test "rejects foreignObject" do
      assert invalid(with_view_box("<foreignObject></foreignObject>")) ==
               {:error, :foreign_object}
    end

    test "rejects javascript: URIs" do
      assert invalid(with_view_box(~s|<a href="javascript:x()"/>|)) == {:error, :javascript_uri}
      assert invalid(with_view_box(~s|<a href="JavaScript:x()"/>|)) == {:error, :javascript_uri}
    end

    test "rejects entity declarations" do
      assert invalid(with_view_box("<!ENTITY a 'b'>")) == {:error, :entity}
    end

    test "rejects event handler attributes" do
      assert invalid(~s|<svg viewBox="0 0 1 1" onload="x()"></svg>|) == {:error, :event_handler}
      assert invalid(with_view_box(~s|<path onclick = "x()"/>|)) == {:error, :event_handler}
      assert invalid(with_view_box(~s|<path ONMOUSEOVER="x()"/>|)) == {:error, :event_handler}
      assert invalid(with_view_box(~s|<path d="M0"onclick="x()"/>|)) == {:error, :event_handler}
      assert invalid(with_view_box("<path\nonfocus='x()'/>")) == {:error, :event_handler}
    end

    test "rejects animations that set an event handler" do
      assert invalid(with_view_box(~s|<set attributeName="onclick" to="x()"/>|)) ==
               {:error, :event_handler}
    end

    test "rejects references to external resources" do
      for url <- ["http://example.test/a.png", "https://example.test/a.png"] do
        assert invalid(with_view_box(~s|<image href="#{url}"/>|)) == {:error, :external_reference}
      end

      assert invalid(with_view_box(~s|<style>@import url(HTTPS://example.test/a.css);</style>|)) ==
               {:error, :external_reference}
    end

    test "a namespace does not hide an external reference" do
      markup =
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1">| <>
          ~s|<image href="http://example.test/a.png"/></svg>|

      assert invalid(markup) == {:error, :external_reference}
    end
  end

  describe "embed!/2" do
    setup do
      dir = Path.join(System.tmp_dir!(), "merchant_icons_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)

      %{dir: dir}
    end

    test "definitions without an icon get icon: nil", %{dir: dir} do
      definitions = [definition(%{icon: nil}), definition(%{id: "other"})]

      assert [%{icon: nil}, %{icon: nil}] = Icons.embed!(definitions, dir)
    end

    test "an empty or missing directory is fine when nothing references it", %{dir: dir} do
      assert [%{icon: nil}] = Icons.embed!([definition(%{icon: nil})], dir)
      assert [%{icon: nil}] = Icons.embed!([definition(%{icon: nil})], Path.join(dir, "missing"))
    end

    test "a reference without a file stops the build", %{dir: dir} do
      assert message(fn -> Icons.embed!([definition(%{icon: "ghost"})], dir) end) =~ "ghost.svg"
    end

    test "an empty file stops the build", %{dir: dir} do
      File.write!(Path.join(dir, "blank.svg"), "")

      assert message(fn -> Icons.embed!([definition(%{icon: "blank"})], dir) end) =~ "empty"
    end

    test "a file with invalid UTF-8 stops the build", %{dir: dir} do
      File.write!(Path.join(dir, "bad.svg"), <<0xFF, 0xFE>>)

      assert message(fn -> Icons.embed!([definition(%{icon: "bad"})], dir) end) =~ "invalid_utf8"
    end

    test "a file that is not an svg stops the build", %{dir: dir} do
      File.write!(Path.join(dir, "text.svg"), "hello")

      assert message(fn -> Icons.embed!([definition(%{icon: "text"})], dir) end) =~ "not_svg"
    end

    test "a file without a merchant stops the build", %{dir: dir} do
      File.write!(Path.join(dir, "orphan.svg"), "hello")

      assert message(fn -> Icons.embed!([definition(%{icon: nil})], dir) end) =~ "orphan"
    end

    test "icon names cannot leave the icons directory", %{dir: dir} do
      for icon_name <- ["../secret", "a/b", "A", "", "with space", "dot.svg"] do
        assert message(fn -> Icons.embed!([definition(%{icon: icon_name})], dir) end) =~
                 "not a valid icon name"
      end
    end

    test "error messages never contain the content of a file", %{dir: dir} do
      File.write!(Path.join(dir, "secret.svg"), "CANARY-4821")

      error = message(fn -> Icons.embed!([definition(%{icon: "secret"})], dir) end)

      refute error =~ "CANARY-4821"
    end
  end
end
