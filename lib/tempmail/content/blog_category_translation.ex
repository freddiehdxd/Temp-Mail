defmodule Tempmail.Content.BlogCategoryTranslation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "blog_category_translations" do
    belongs_to :category, Tempmail.Content.BlogCategory
    field :locale, :string
    field :name, :string
    field :description, :string
  end

  def changeset(translation, attrs) do
    translation
    |> cast(attrs, [:category_id, :locale, :name, :description])
    |> validate_required([:locale, :name])
    |> unique_constraint([:category_id, :locale])
  end
end
