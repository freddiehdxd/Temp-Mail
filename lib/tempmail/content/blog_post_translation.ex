defmodule Tempmail.Content.BlogPostTranslation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "blog_post_translations" do
    belongs_to :post, Tempmail.Content.BlogPost

    field :locale, :string
    field :title, :string
    field :excerpt, :string
    field :content, :string
    field :meta_title, :string
    field :meta_description, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(translation, attrs) do
    translation
    |> cast(attrs, [:post_id, :locale, :title, :excerpt, :content, :meta_title, :meta_description])
    |> validate_required([:locale, :title, :content])
    |> unique_constraint([:post_id, :locale])
  end
end
