defmodule Tempmail.Mail.TempEmailSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "temp_email_sessions" do
    belongs_to :user, Tempmail.Accounts.User

    field :address, :string
    field :domain, :string
    field :expires_at, :utc_datetime
    field :is_permanent, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:user_id, :address, :domain, :expires_at, :is_permanent])
    |> update_change(:address, &String.downcase/1)
    |> update_change(:domain, &String.downcase/1)
    |> validate_required([:address, :domain, :expires_at])
    |> unique_constraint(:address)
  end
end
