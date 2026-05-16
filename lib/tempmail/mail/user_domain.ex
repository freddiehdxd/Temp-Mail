defmodule Tempmail.Mail.UserDomain do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_domains" do
    belongs_to :user, Tempmail.Accounts.User
    field :domain, :string
    field :verification_token, :string
    field :is_verified, :boolean, default: false
    field :verified_at, :utc_datetime
    field :mx_verified, :boolean, default: false
    field :spf_verified, :boolean, default: false
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(user_domain, attrs) do
    user_domain
    |> cast(attrs, [
      :user_id,
      :domain,
      :verification_token,
      :is_verified,
      :verified_at,
      :mx_verified,
      :spf_verified,
      :is_active
    ])
    |> put_verification_token()
    |> update_change(:domain, &String.downcase/1)
    |> validate_required([:user_id, :domain, :verification_token])
    |> validate_format(:domain, ~r/^[a-z0-9.-]+\.[a-z]{2,}$/)
    |> unique_constraint(:domain)
    |> unique_constraint(:verification_token)
  end

  defp put_verification_token(changeset) do
    case get_field(changeset, :verification_token) do
      nil -> put_change(changeset, :verification_token, Ecto.UUID.generate())
      _ -> changeset
    end
  end
end
