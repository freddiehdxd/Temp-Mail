defmodule Tempmail.Repo.Migrations.CreateTempmailTables do
  use Ecto.Migration

  def change do
    create table(:domains, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain, :string, null: false
      add :is_active, :boolean, null: false, default: true
      add :is_default, :boolean, null: false, default: false
      add :mailcow_id, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:domains, [:domain])

    create table(:settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :text, null: false
      add :type, :string, null: false, default: "string"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:settings, [:key])

    create table(:email_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date, null: false
      add :generated, :integer, null: false, default: 0
      add :received, :integer, null: false, default: 0
      add :domain_id, references(:domains, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:email_stats, [:date, :domain_id])

    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :action, :string, null: false
      add :target, :string
      add :details, :text
      add :ip_address, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create table(:user_domains, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :domain, :string, null: false
      add :verification_token, :string, null: false
      add :is_verified, :boolean, null: false, default: false
      add :verified_at, :utc_datetime
      add :mx_verified, :boolean, null: false, default: false
      add :spf_verified, :boolean, null: false, default: false
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_domains, [:domain])
    create unique_index(:user_domains, [:verification_token])
    create index(:user_domains, [:user_id])

    create table(:user_mailboxes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :address, :string, null: false
      add :prefix, :string, null: false
      add :domain, :string, null: false
      add :name, :string
      add :is_active, :boolean, null: false, default: true
      add :is_primary, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_mailboxes, [:address])
    create index(:user_mailboxes, [:user_id])

    create table(:user_emails, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :mailbox_id, references(:user_mailboxes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :from, :string, null: false
      add :from_name, :string
      add :subject, :string, null: false, default: "(No Subject)"
      add :text, :text
      add :html, :text
      add :received_at, :utc_datetime, null: false
      add :read, :boolean, null: false, default: false
      add :starred, :boolean, null: false, default: false
      add :archived, :boolean, null: false, default: false
      add :attachments, :map

      timestamps(type: :utc_datetime)
    end

    create index(:user_emails, [:mailbox_id])
    create index(:user_emails, [:received_at])
    create index(:user_emails, [:read])

    create table(:temp_email_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :address, :string, null: false
      add :domain, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :is_permanent, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:temp_email_sessions, [:address])
    create index(:temp_email_sessions, [:user_id])
    create index(:temp_email_sessions, [:expires_at])

    create table(:blog_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, null: false, default: "DRAFT"
      add :featured_image, :text
      add :published_at, :utc_datetime
      add :view_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_posts, [:slug])
    create index(:blog_posts, [:status])
    create index(:blog_posts, [:published_at])

    create table(:blog_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :is_active, :boolean, null: false, default: true
      add :sort_order, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_categories, [:slug])
    create index(:blog_categories, [:is_active])
    create index(:blog_categories, [:sort_order])

    create table(:blog_post_translations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:blog_posts, type: :binary_id, on_delete: :delete_all), null: false
      add :locale, :string, null: false
      add :title, :string, null: false
      add :excerpt, :text
      add :content, :text, null: false
      add :meta_title, :string
      add :meta_description, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:blog_post_translations, [:post_id, :locale])
    create index(:blog_post_translations, [:locale])

    create table(:blog_category_translations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :category_id, references(:blog_categories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :locale, :string, null: false
      add :name, :string, null: false
      add :description, :text
    end

    create unique_index(:blog_category_translations, [:category_id, :locale])
    create index(:blog_category_translations, [:locale])

    create table(:blog_categories_posts, primary_key: false) do
      add :post_id, references(:blog_posts, type: :binary_id, on_delete: :delete_all), null: false

      add :category_id, references(:blog_categories, type: :binary_id, on_delete: :delete_all),
        null: false
    end

    create unique_index(:blog_categories_posts, [:post_id, :category_id])
  end
end
