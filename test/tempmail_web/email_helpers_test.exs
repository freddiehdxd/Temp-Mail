defmodule TempmailWeb.EmailHelpersTest do
  use ExUnit.Case, async: true

  import TempmailWeb.EmailHelpers

  # Regression: senders (e.g. Evoto) deliver an empty text/plain part next to
  # the real HTML body; the viewer must fall back to HTML, not show a blank.
  @html_only %{
    "text" => "",
    "html" => "<html><head><title>Ignore</title></head><body><p>Code: <b>3443</b></p></body></html>"
  }

  describe "presence/1" do
    test "nil and blank strings are nil" do
      assert presence(nil) == nil
      assert presence("") == nil
      assert presence("  \n") == nil
    end

    test "keeps non-blank values" do
      assert presence("hello") == "hello"
    end
  end

  describe "email_html?/1" do
    test "false for missing or blank html" do
      refute email_html?(%{"html" => nil})
      refute email_html?(%{"html" => ""})
    end

    test "true for a real html body" do
      assert email_html?(@html_only)
    end
  end

  describe "email_srcdoc/1" do
    test "prepends base target so links open in a new tab" do
      assert email_srcdoc(@html_only) =~ ~s(<base target="_blank">)
      assert email_srcdoc(@html_only) =~ "Code: <b>3443</b>"
    end
  end

  describe "email_preview/1" do
    test "prefers non-blank text" do
      assert email_preview(%{"text" => "plain body", "html" => "<p>rich</p>"}) == "plain body"
    end

    test "falls back to stripped html when text is empty" do
      assert email_preview(@html_only) == "Code: 3443"
    end

    test "empty email yields empty preview" do
      assert email_preview(%{"text" => nil, "html" => nil}) == ""
    end
  end
end
