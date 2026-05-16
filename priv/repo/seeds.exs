alias Tempmail.Mail

default_domain = Application.get_env(:tempmail, :default_domain, "tempmail.com")

case Mail.create_domain(%{
       domain: default_domain,
       is_active: true,
       is_default: true,
       description: "Default generated-address domain"
     }) do
  {:ok, _domain} -> :ok
  {:error, _changeset} -> :ok
end
