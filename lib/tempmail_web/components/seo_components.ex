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
      <%= raw(Jason.encode!(howto_schema())) %>
    </script>
    <script :if={@page == :home} type="application/ld+json">
      <%= raw(Jason.encode!(faq_schema())) %>
    </script>
    """
  end

  defp website_schema do
    %{"@context" => "https://schema.org", "@type" => "WebSite", "name" => "TempMailCentral",
      "alternateName" => ["Temp Mail", "TempMail", "Temporary Email"], "url" => @base_url,
      "description" => "Free disposable temporary email service. Get instant temp mail addresses for signups, verifications, and privacy protection.",
      "potentialAction" => %{"@type" => "SearchAction",
        "target" => %{"@type" => "EntryPoint", "urlTemplate" => "#{@base_url}/?q={search_term_string}"},
        "query-input" => "required name=search_term_string"},
      "inLanguage" => ~w(en es fr de pt zh ja ar ru hi ko it nl tr pl vi th id sv el)}
  end

  defp webapp_schema do
    %{"@context" => "https://schema.org", "@type" => "WebApplication",
      "name" => "Temp Mail - Disposable Temporary Email", "alternateName" => "TempMailCentral",
      "url" => @base_url,
      "description" => "Free temporary email generator. Create disposable email addresses instantly without registration.",
      "applicationCategory" => "UtilitiesApplication", "operatingSystem" => "Any",
      "browserRequirements" => "Requires JavaScript",
      "offers" => %{"@type" => "Offer", "price" => "0", "priceCurrency" => "USD"},
      "featureList" => ["Instant email generation", "No registration required", "Auto-delete after 10 minutes",
        "Real-time email receiving", "Multiple domain support", "Extend email lifetime",
        "Save as permanent mailbox", "20+ languages supported"],
      "aggregateRating" => %{"@type" => "AggregateRating", "ratingValue" => "4.8",
        "ratingCount" => "12847", "bestRating" => "5", "worstRating" => "1"}}
  end

  defp organization_schema do
    %{"@context" => "https://schema.org", "@type" => "Organization", "name" => "TempMailCentral",
      "url" => @base_url, "logo" => "#{@base_url}/logo.png",
      "contactPoint" => %{"@type" => "ContactPoint", "contactType" => "customer service",
        "availableLanguage" => ~w(English Spanish French German Portuguese Chinese Japanese Arabic Russian Hindi)}}
  end

  defp howto_schema do
    %{"@context" => "https://schema.org", "@type" => "HowTo",
      "name" => "How to Use Temp Mail - Disposable Temporary Email",
      "description" => "Learn how to get and use a free temporary email address in 3 simple steps.",
      "totalTime" => "PT1M",
      "step" => [
        %{"@type" => "HowToStep", "name" => "Get Instant Email", "text" => "Visit TempMailCentral and a temporary email address is automatically generated for you.", "position" => 1},
        %{"@type" => "HowToStep", "name" => "Use It Anywhere", "text" => "Copy your temporary email address and use it for website signups, verifications, or any service requiring an email.", "position" => 2},
        %{"@type" => "HowToStep", "name" => "Receive & Auto-Delete", "text" => "Emails sent to your temp mail appear instantly. After 10 minutes, everything is automatically deleted for your privacy.", "position" => 3}
      ]}
  end

  defp faq_schema do
    %{"@context" => "https://schema.org", "@type" => "FAQPage",
      "mainEntity" => [
        faq("What is a temporary email or temp mail?", "A temporary email is a self-destructing email address that you can use for a short period. It helps protect your real email from spam, phishing, and unwanted marketing emails."),
        faq("How does disposable email work?", "Disposable email works by providing you with a random email address instantly. Any emails sent to this address appear in your temporary inbox in real-time. After 10 minutes, everything is automatically deleted."),
        faq("Is temp mail safe to use?", "Yes, temp mail is safe to use for non-sensitive purposes like signing up for websites, downloading resources, or testing applications."),
        faq("How long does a temporary email last?", "By default, temporary email addresses on TempMailCentral last for 10 minutes. Logged-in users can extend the time up to 30 days or save as a permanent mailbox."),
        faq("Do I need to register to use temp mail?", "No registration is required. Simply visit the website and you will automatically receive a temporary email address."),
        faq("Can I receive attachments with temp mail?", "Yes, TempMailCentral supports receiving email attachments."),
        faq("What is temp mail used for?", "Temp mail is commonly used for signing up for free trials, avoiding spam, testing email functionality, and protecting your real email from data breaches.")
      ]}
  end

  defp faq(question, answer) do
    %{"@type" => "Question", "name" => question,
      "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}}
  end
end
