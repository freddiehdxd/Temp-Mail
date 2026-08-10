defmodule Tempmail.Repo.Migrations.CreateContactMessages do
  use Ecto.Migration

  def change do
    create table(:contact_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :email, :string
      add :topic, :string, null: false, default: "support"
      add :body, :text, null: false
      add :ip_address, :string
      add :read, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:contact_messages, [:inserted_at])
    create index(:contact_messages, [:read])
  end
end
