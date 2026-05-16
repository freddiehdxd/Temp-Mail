defmodule Tempmail.Mail.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "audit_logs" do
    belongs_to :user, Tempmail.Accounts.User
    field :action, :string
    field :target, :string
    field :details, :string
    field :ip_address, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:user_id, :action, :target, :details, :ip_address])
    |> validate_required([:action])
  end
end
