defmodule Tempmail.Content.BlogCategory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "blog_categories" do
    has_many :translations, Tempmail.Content.BlogCategoryTranslation, foreign_key: :category_id

    many_to_many :posts, Tempmail.Content.BlogPost,
      join_through: "blog_categories_posts",
      join_keys: [category_id: :id, post_id: :id]

    field :slug, :string
    field :is_active, :boolean, default: true
    field :sort_order, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:slug, :is_active, :sort_order])
    |> validate_required([:slug])
    |> unique_constraint(:slug)
    |> cast_assoc(:translations)
  end
end
