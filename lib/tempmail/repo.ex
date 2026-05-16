defmodule Tempmail.Repo do
  use Ecto.Repo,
    otp_app: :tempmail,
    adapter: Ecto.Adapters.Postgres
end
