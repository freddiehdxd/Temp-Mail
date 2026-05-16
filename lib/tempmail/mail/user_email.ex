defmodule Tempmail.Mail.UserEmail do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_emails" do
    belongs_to :mailbox, Tempmail.Mail.UserMailbox

    field :from, :string
    field :from_name, :string
    field :subject, :string, default: "(No Subject)"
    field :text, :string
    field :html, :string
    field :received_at, :utc_datetime
    field :read, :boolean, default: false
    field :starred, :boolean, default: false
    field :archived, :boolean, default: false
    field :attachments, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [
      :mailbox_id,
      :from,
      :from_name,
      :subject,
      :text,
      :html,
      :received_at,
      :read,
      :starred,
      :archived,
      :attachments
    ])
    |> put_default_received_at()
    |> validate_required([:mailbox_id, :from, :subject, :received_at])
  end

  defp put_default_received_at(changeset) do
    case get_field(changeset, :received_at) do
      nil -> put_change(changeset, :received_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
