defmodule Tempmail.Content.BlogPost do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "blog_posts" do
    belongs_to :author, Tempmail.Accounts.User
    has_many :translations, Tempmail.Content.BlogPostTranslation, foreign_key: :post_id
    many_to_many :categories, Tempmail.Content.BlogCategory, join_through: "blog_categories_posts"

    field :slug, :string
    field :status, :string, default: "DRAFT"
    field :featured_image, :string
    field :published_at, :utc_datetime
    field :view_count, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:slug, :author_id, :status, :featured_image, :published_at, :view_count])
    |> update_change(:slug, &slugify/1)
    |> validate_required([:slug, :status])
    |> validate_inclusion(:status, ["DRAFT", "PUBLISHED", "ARCHIVED"])
    |> unique_constraint(:slug)
    |> cast_assoc(:translations)
  end

  defp slugify(value) when is_binary(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp slugify(value), do: value
end
