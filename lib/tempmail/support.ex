defmodule Tempmail.Support do
  @moduledoc """
  Contact/support messages submitted through the public contact form.
  Messages are stored in Postgres and surfaced in the admin dashboard.
  """

  import Ecto.Query, warn: false

  alias Tempmail.Repo
  alias Tempmail.Support.ContactMessage

  def change_contact_message(%ContactMessage{} = message, attrs \\ %{}) do
    ContactMessage.changeset(message, attrs)
  end

  def create_contact_message(attrs) do
    %ContactMessage{}
    |> ContactMessage.changeset(attrs)
    |> Repo.insert()
  end

  def list_recent_contact_messages(limit \\ 20) do
    ContactMessage
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def count_unread_contact_messages do
    ContactMessage |> where([m], m.read == false) |> Repo.aggregate(:count)
  end

  def mark_contact_message_read(id) do
    case Repo.get(ContactMessage, id) do
      nil -> {:error, :not_found}
      message -> message |> Ecto.Changeset.change(read: true) |> Repo.update()
    end
  end
end
