defmodule Tempmail.Mail.EmailStat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "email_stats" do
    field :date, :date
    field :generated, :integer, default: 0
    field :received, :integer, default: 0
    belongs_to :domain, Tempmail.Mail.Domain

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(stat, attrs) do
    stat
    |> cast(attrs, [:date, :generated, :received, :domain_id])
    |> validate_required([:date])
    |> unique_constraint([:date, :domain_id])
  end
end
