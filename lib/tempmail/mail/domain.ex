defmodule Tempmail.Mail.Domain do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "domains" do
    field :domain, :string
    field :is_active, :boolean, default: true
    field :is_default, :boolean, default: false
    field :mailcow_id, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(domain, attrs) do
    domain
    |> cast(attrs, [:domain, :is_active, :is_default, :mailcow_id, :description])
    |> update_change(:domain, &String.downcase/1)
    |> validate_required([:domain])
    |> validate_format(:domain, ~r/^[a-z0-9.-]+\.[a-z]{2,}$/)
    |> unique_constraint(:domain)
  end
end
