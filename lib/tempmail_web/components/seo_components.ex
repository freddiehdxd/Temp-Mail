defmodule TempmailWeb.SEOComponents do
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  @base_url "https://tempmailcentral.com"

  attr :page, :atom, default: :other

  def structured_data(assigns) do
    ~H"""
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(website_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(webapp_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(organization_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(faq_schema())) %>
    </script>
    """
  end

  defp website_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => "TempMail Central",
      "url" => @base_url,
      "description" =>
        "Free temporary email service. Generate a disposable inbox that expires automatically, or keep it longer with a free account.",
      "inLanguage" => ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)
    }
  end

  defp webapp_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "WebApplication",
      "name" => "TempMail Central",
      "url" => @base_url,
      "description" =>
        "Temporary email generator. Create a disposable address instantly without registration; inboxes expire after 10 minutes by default and can be extended or saved with a free account.",
      "applicationCategory" => "UtilitiesApplication",
      "operatingSystem" => "Any",
      "browserRequirements" => "Requires JavaScript",
      "offers" => %{"@type" => "Offer", "price" => "0", "priceCurrency" => "USD"},
      "featureList" => [
        "Instant address generation without registration",
        "Real-time inbox updates",
        "Inboxes expire after 10 minutes by default",
        "Extend an inbox up to 24 hours without an account, or 30 days with one",
        "Save an address as a permanent mailbox with a free account",
        "Attachment viewing and download",
        "Custom domains for registered users",
        "Interface available in 20 languages"
      ]
    }
  end

  defp organization_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => "TempMail Central",
      "url" => @base_url,
      "logo" => "#{@base_url}/images/logo.svg",
      "contactPoint" => %{
        "@type" => "ContactPoint",
        "contactType" => "customer service",
        "url" => "#{@base_url}/contact",
        "email" => "contact@tempmailcentral.com"
      }
    }
  end

  defp faq_schema do
    %{
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => [
        faq(
          "What is a temporary email address?",
          "A temporary email address is a randomly generated, disposable inbox you can use instead of your real address. Mail sent to it appears in your browser, and the inbox deletes itself automatically when its timer runs out."
        ),
        faq(
          "How long does a TempMail Central inbox last?",
          "By default an inbox lasts 10 minutes. Anyone can extend it to 1 hour or 24 hours; signed-in users can extend it up to 30 days or save the address as a permanent mailbox that is kept until they delete it."
        ),
        faq(
          "Do I need to register?",
          "No. An address is generated the moment you open the site. A free account is only needed if you want inboxes that last longer than 24 hours, permanent mailboxes, or custom domains."
        ),
        faq(
          "What happens when an inbox expires?",
          "Temporary inboxes are stored in memory with a time-to-live. When the timer lapses, the address and every message in it are deleted and cannot be recovered. Expired temporary mail is not archived or backed up."
        ),
        faq(
          "Can I receive attachments?",
          "Yes. Attachments arriving with a message can be viewed and downloaded while the inbox is active."
        ),
        faq(
          "Is temporary email safe to use?",
          "It is well suited to one-off signups, downloads, and testing. It is not suited to accounts you may need to recover later, such as banking or government services, because mail is deleted permanently when the inbox expires."
        )
      ]
    }
  end

  defp faq(question, answer) do
    %{
      "@type" => "Question",
      "name" => question,
      "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}
    }
  end
end
