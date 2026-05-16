defmodule Tempmail.Mail.UserMailbox do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_mailboxes" do
    belongs_to :user, Tempmail.Accounts.User
    has_many :emails, Tempmail.Mail.UserEmail, foreign_key: :mailbox_id

    field :address, :string
    field :prefix, :string
    field :domain, :string
    field :name, :string
    field :is_active, :boolean, default: true
    field :is_primary, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(mailbox, attrs) do
    mailbox
    |> cast(attrs, [:user_id, :address, :prefix, :domain, :name, :is_active, :is_primary])
    |> normalize_address()
    |> validate_required([:user_id, :address, :prefix, :domain])
    |> validate_format(:address, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> unique_constraint(:address)
  end

  defp normalize_address(changeset) do
    changeset
    |> update_change(:address, &String.downcase/1)
    |> update_change(:domain, &String.downcase/1)
  end
end
