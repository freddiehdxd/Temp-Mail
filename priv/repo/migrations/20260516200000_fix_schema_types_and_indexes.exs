defmodule Tempmail.Repo.Migrations.FixSchemaTypesAndIndexes do
  use Ecto.Migration

  def change do
    alter table(:settings) do
      modify :value, :text, from: :string
    end

    alter table(:audit_logs) do
      modify :details, :text, from: :string
    end

    create index(:blog_posts, [:author_id])

    alter table(:blog_category_translations) do
      add :inserted_at, :utc_datetime, default: fragment("NOW()")
      add :updated_at, :utc_datetime, default: fragment("NOW()")
    end
  end
end
