defmodule Tempmail.Mail.Setting do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "settings" do
    field :key, :string
    field :value, :string
    field :type, :string, default: "string"

    timestamps(type: :utc_datetime)
  end

  def changeset(setting, attrs) do
    setting
    |> cast(attrs, [:key, :value, :type])
    |> validate_required([:key, :value, :type])
    |> unique_constraint(:key)
  end
end
