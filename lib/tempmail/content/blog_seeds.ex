defmodule Tempmail.Content.BlogSeeds do
  @moduledoc """
  Publishes the built-in English blog articles stored under `priv/blog_seeds/`.

  Each article is a pair of files: `<slug>.html` (the body) and `<slug>.json`
  (title, excerpt, meta_title, meta_description). Seeding is idempotent:
  slugs that already exist in the database are left untouched, so re-running
  after adding a new article only inserts the new one. Translations for other
  locales can be added later through the admin blog editor.

  Run in dev with `mix run priv/repo/blog_seeds.exs` and in production with
  `bin/tempmail eval "Tempmail.Release.seed_blog()"`.
  """

  import Ecto.Query, warn: false

  alias Tempmail.Content
  alias Tempmail.Content.BlogPost
  alias Tempmail.Repo

  @slugs ~w(
    when-temporary-email-is-safe-to-use
    when-not-to-use-disposable-email
    temporary-email-vs-email-aliases
    how-temporary-inbox-deletion-works
    how-we-generate-addresses-and-prevent-abuse
    temporary-email-for-software-testing
    can-websites-detect-temp-mail
    protect-your-primary-inbox-from-spam
    phishing-risks-and-disposable-email
    custom-domains-and-permanent-mailboxes
  )

  def run do
    author_id = default_author_id()

    results =
      Enum.map(@slugs, fn slug ->
        if Repo.exists?(from(p in BlogPost, where: p.slug == ^slug)) do
          {slug, :exists}
        else
          seed_post(slug, author_id)
        end
      end)

    Enum.each(results, fn {slug, status} -> IO.puts("  #{slug}: #{status}") end)
    results
  end

  defp seed_post(slug, author_id) do
    dir = Path.join(:code.priv_dir(:tempmail), "blog_seeds")
    content = File.read!(Path.join(dir, "#{slug}.html"))
    meta = Path.join(dir, "#{slug}.json") |> File.read!() |> Jason.decode!()

    attrs = %{
      "slug" => slug,
      "status" => "PUBLISHED",
      "published_at" => DateTime.utc_now() |> DateTime.truncate(:second),
      "author_id" => author_id,
      "translations" => %{
        "en" => %{
          "title" => Map.fetch!(meta, "title"),
          "excerpt" => Map.get(meta, "excerpt"),
          "content" => content,
          "meta_title" => Map.get(meta, "meta_title"),
          "meta_description" => Map.get(meta, "meta_description")
        }
      }
    }

    case Content.upsert_post(attrs) do
      {:ok, _post} -> {slug, :created}
      {:error, reason} -> {slug, {:error, reason}}
    end
  end

  defp default_author_id do
    Repo.one(
      from(u in Tempmail.Accounts.User,
        where: u.role in ["SUPER_ADMIN", "ADMIN"],
        order_by: [asc: u.inserted_at],
        limit: 1,
        select: u.id
      )
    )
  end
end
