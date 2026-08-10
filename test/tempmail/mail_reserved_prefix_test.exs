defmodule Tempmail.MailReservedPrefixTest do
  use Tempmail.DataCase, async: true

  import Tempmail.AccountsFixtures

  alias Tempmail.Mail

  setup do
    {:ok, domain} =
      Mail.create_domain(%{"domain" => "sys-example.test", "is_active" => true})

    %{domain: domain}
  end

  test "regular users cannot claim reserved prefixes on system domains", %{domain: domain} do
    user = user_fixture()

    assert {:error, :reserved_prefix} =
             Mail.create_user_mailbox(user, %{
               "prefix" => "contact",
               "domain" => domain.domain
             })

    assert {:error, :reserved_prefix} =
             Mail.create_user_mailbox(user, %{"address" => "support@#{domain.domain}"})
  end

  test "regular users can still create normal mailboxes", %{domain: domain} do
    user = user_fixture()

    assert {:ok, mailbox} =
             Mail.create_user_mailbox(user, %{
               "prefix" => "myinbox",
               "domain" => domain.domain
             })

    assert mailbox.address == "myinbox@#{domain.domain}"
  end

  test "admins may claim reserved prefixes on system domains", %{domain: domain} do
    admin = user_fixture()
    {:ok, admin} = admin |> Ecto.Changeset.change(role: "ADMIN") |> Tempmail.Repo.update()

    assert {:ok, mailbox} =
             Mail.create_user_mailbox(admin, %{
               "prefix" => "contact",
               "domain" => domain.domain
             })

    assert mailbox.address == "contact@#{domain.domain}"
  end
end
