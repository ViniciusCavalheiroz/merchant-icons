defmodule MerchantIcons.IconsTest do
  use ExUnit.Case, async: true

  alias MerchantIcons.Icons

  # The markup below is the smallest text that satisfies or violates each rule. It is not a logo
  # and is never written to priv/icons.
  @minimal ~s|<svg viewBox="0 0 1 1"></svg>|

  @icons_dir Path.expand("../../priv/icons", __DIR__)

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

  describe "validate/1 hardening" do
    test "rejects embedded HTML elements" do
      for tag <- ["iframe", "object", "embed", "IFRAME"] do
        assert invalid(with_view_box("<#{tag} srcdoc=x></#{tag}>")) ==
                 {:error, :embedded_content}
      end
    end

    test "rejects javascript: hidden by character references or whitespace" do
      assert invalid(with_view_box(~s|<a href="jav&#97;script:x()"/>|)) == {:error, :entity}
      assert invalid(with_view_box(~s|<a href="javascript&colon;x()"/>|)) == {:error, :entity}
      assert invalid(with_view_box("<a href=\"java\tscript:x()\"/>")) == {:error, :javascript_uri}
      assert invalid(with_view_box("<a href=\"java\nscript:x()\"/>")) == {:error, :javascript_uri}
    end

    test "rejects any ampersand" do
      assert invalid(with_view_box("<text>&amp;</text>")) == {:error, :entity}
    end

    test "rejects data: URIs" do
      assert invalid(with_view_box(~s|<image href="data:image/png;base64,AAAA"/>|)) ==
               {:error, :data_uri}
    end

    test "rejects a doctype" do
      assert invalid(with_view_box("<!DOCTYPE svg>")) == {:error, :doctype}
    end

    test "rejects event handlers after a form feed" do
      assert invalid(~s|<svg viewBox="0 0 1 1"\fonload="x()"></svg>|) == {:error, :event_handler}
    end

    test "rejects animations that set an event handler, however they are written" do
      for markup <- [
            ~s|<set attributeName = "onclick" to="x()"/>|,
            ~s|<set attributeName=onclick to="x()"/>|,
            ~s|<set attributeName='onclick' to="x()"/>|
          ] do
        assert invalid(with_view_box(markup)) == {:error, :event_handler}
      end
    end

    test "rejects protocol-relative and other external schemes" do
      for url <- ["//example.test/a.png", "ftp://example.test/a.png", "file:///etc/passwd"] do
        assert invalid(with_view_box(~s|<image href="#{url}"/>|)) == {:error, :external_reference}
      end
    end

    test "rejects references that do not point inside the document" do
      for markup <- [
            ~s|<image href="a.png"/>|,
            ~s|<image src="a.png"/>|,
            ~s|<use xlink:href="/a.svg#b"/>|,
            ~s|<style>.a{fill:url(a.svg#b)}</style>|,
            ~s|<style>@import "a.css";</style>|
          ] do
        assert invalid(with_view_box(markup)) == {:error, :external_reference}
      end
    end

    test "accepts references to ids inside the document" do
      markup =
        with_view_box(
          ~s|<defs><linearGradient id="a"/></defs>| <>
            ~s|<use href="#a"/><use xlink:href='#a'/>| <>
            ~s|<rect fill="url(#a)"/><rect fill="url('#a')"/>|
        )

      assert Icons.validate(markup) == {:ok, markup}
    end

    test "nothing may follow the closing tag" do
      assert invalid(@minimal <> "<p>x</p>") == {:error, :trailing_content}
      assert invalid(@minimal <> "<iframe></iframe>") == {:error, :trailing_content}
    end

    test "accepts exactly the size limit and rejects one byte more" do
      padding = String.duplicate(" ", Icons.max_bytes() - byte_size(@minimal))
      exact = ~s|<svg viewBox="0 0 1 1">| <> padding <> "</svg>"

      assert byte_size(exact) == Icons.max_bytes()
      assert Icons.validate(exact) == {:ok, exact}
      assert invalid(exact <> " ") == {:error, :too_large}
    end

    test "the size is checked before the content" do
      assert invalid(String.duplicate(<<0xFF>>, Icons.max_bytes() + 1)) == {:error, :too_large}
    end

    test "every icon shipped in priv/icons is valid" do
      files = Icons.files(@icons_dir)

      assert files != []

      for file <- files do
        content = File.read!(file)

        assert Icons.validate(content) == {:ok, content},
               "#{Path.basename(file)} is not a valid icon"
      end
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

    test "a link instead of a regular file stops the build", %{dir: dir} do
      File.write!(Path.join(dir, "real.txt"), @minimal)
      :ok = File.ln_s("real.txt", Path.join(dir, "linked.svg"))

      assert message(fn -> Icons.embed!([definition(%{icon: "linked"})], dir) end) =~
               "regular file"
    end

    test "an oversized file stops the build without being read", %{dir: dir} do
      File.write!(Path.join(dir, "huge.svg"), String.duplicate("a", Icons.max_bytes() + 1))

      assert message(fn -> Icons.embed!([definition(%{icon: "huge"})], dir) end) =~ "too_large"
    end

    test "error messages never contain the content of a file", %{dir: dir} do
      File.write!(Path.join(dir, "secret.svg"), "CANARY-4821")

      error = message(fn -> Icons.embed!([definition(%{icon: "secret"})], dir) end)

      refute error =~ "CANARY-4821"
    end
  end

  describe "validate/1 element allowlist" do
    # S1: HTML between two svg roots would end up outside the svg when inlined.
    test "rejects content between two svg roots" do
      markup = @minimal <> "<div>outside</div>" <> @minimal

      assert invalid(markup) == {:error, {:disallowed_element, "div"}}
      assert invalid(@minimal <> @minimal) == {:error, :trailing_content}
    end

    # S2: HTML elements that break out of the svg, and a form with a relative action.
    test "rejects html elements, including ones that break out of the svg" do
      assert invalid(with_view_box(~s|<p><form action="/transfer" method="post"></form></p>|)) ==
               {:error, {:disallowed_element, "p"}}

      for element <- ~w(div p form button img input table a span body) do
        assert invalid(with_view_box("<#{element}></#{element}>")) ==
                 {:error, {:disallowed_element, element}}
      end
    end

    # S3: CSS can reference resources in ways the url( check does not see.
    test "rejects style elements" do
      assert invalid(with_view_box(~s|<style>*{background:image-set("x.png" 1x)}</style>|)) ==
               {:error, {:disallowed_element, "style"}}
    end

    # S4: SMIL animation can rewrite href at runtime.
    test "rejects animation elements" do
      markup = with_view_box(~s|<a><animate attributeName = "href" to="/x"/></a>|)

      assert invalid(markup) == {:error, {:disallowed_element, "a"}}

      assert invalid(with_view_box(~s|<animate attributeName="fill" to="red"/>|)) ==
               {:error, {:disallowed_element, "animate"}}
    end

    test "names the first rejected element" do
      markup = with_view_box("<path/><text>x</text><style></style>")

      assert invalid(markup) == {:error, {:disallowed_element, "text"}}
    end

    test "element names are case-sensitive and must be known" do
      assert invalid(with_view_box("<Path/>")) == {:error, {:disallowed_element, "Path"}}

      assert invalid(with_view_box("<unknown-element/>")) ==
               {:error, {:disallowed_element, "unknown-element"}}
    end

    test "rejects markup that is not an element" do
      assert {:error, {:disallowed_element, _name}} = invalid(with_view_box("<!-- comment -->"))
      assert {:error, {:disallowed_element, _name}} = invalid(with_view_box("<![CDATA[x]]>"))
      assert {:error, {:disallowed_element, _name}} = invalid(with_view_box("<?pi x?>"))
      assert {:error, {:disallowed_element, ""}} = invalid(with_view_box("< path/>"))
    end

    test "an element name that is too long is cut" do
      long = String.duplicate("a", 500)

      assert {:error, {:disallowed_element, name}} = invalid(with_view_box("<#{long}/>"))
      assert byte_size(name) <= 40
    end

    test "rejects an unbalanced svg" do
      assert invalid(~s|<svg viewBox="0 0 1 1"><svg></svg>|) == {:error, :unbalanced_svg}
    end

    test "accepts nested svg elements and the allowed drawing elements" do
      markup =
        with_view_box(
          ~s|<defs><linearGradient id="a"><stop offset="0"/></linearGradient>| <>
            ~s|<clipPath id="c"><rect/></clipPath><filter id="f"><feGaussianBlur/></filter>| <>
            ~s|<pattern id="p" width="1" height="1"><rect/></pattern></defs>| <>
            ~s|<g><path d="M0 0"/><circle/></g><svg viewBox="0 0 1 1"><rect/></svg>|
        )

      assert Icons.validate(markup) == {:ok, markup}
    end

    test "every bundled icon passes validation" do
      files = Icons.files(@icons_dir)

      assert files != []

      for path <- files do
        assert {:ok, _svg} = Icons.validate(File.read!(path)), "#{Path.basename(path)} is invalid"
      end
    end
  end

  describe "embed!/2 message for a rejected element" do
    setup do
      dir = Path.join(System.tmp_dir!(), "merchant_icons_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf!(dir) end)
      %{dir: dir}
    end

    test "names the rejected element", %{dir: dir} do
      File.write!(Path.join(dir, "logo.svg"), with_view_box("<path/><text>x</text>"))

      error = message(fn -> Icons.embed!([definition(%{icon: "logo"})], dir) end)

      assert error =~ "disallowed_element"
      assert error =~ ~s|"text"|
    end
  end
end
