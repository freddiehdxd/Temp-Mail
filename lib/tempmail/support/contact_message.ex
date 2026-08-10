defmodule Tempmail.Support.ContactMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @topics ~w(support privacy abuse feedback other)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "contact_messages" do
    field :name, :string
    field :email, :string
    field :topic, :string, default: "support"
    field :body, :string
    field :ip_address, :string
    field :read, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def topics, do: @topics

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:name, :email, :topic, :body, :ip_address])
    |> validate_required([:topic, :body])
    |> validate_inclusion(:topic, @topics)
    |> validate_length(:name, max: 120)
    |> validate_length(:body,
      min: 10,
      max: 5000,
      message: "should be between 10 and 5000 characters"
    )
    |> validate_email_if_present()
  end

  defp validate_email_if_present(changeset) do
    case get_change(changeset, :email) do
      nil ->
        changeset

      _ ->
        changeset
        |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
          message: "doesn't look like an email address"
        )
        |> validate_length(:email, max: 160)
    end
  end
end
