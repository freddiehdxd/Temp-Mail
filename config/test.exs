import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :pbkdf2_elixir, :rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
test_database_url = System.get_env("TEST_DATABASE_URL")

test_repo_config =
  if test_database_url do
    [url: test_database_url]
  else
    [
      username: "tempmail_phoenix",
      password: "tempmail_phoenix",
      hostname: "localhost",
      database: "tempmail_phoenix_test#{System.get_env("MIX_TEST_PARTITION")}"
    ]
  end

config :tempmail, Tempmail.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :tempmail, Tempmail.Repo, test_repo_config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :tempmail, TempmailWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "s2DM+AMHiu4GgqNcKnt+eWg3aHwaUtalHeW8dhnpU7m8Uv3GNhluMuP6id6Z7FZd",
  server: false

# In test we don't send emails
config :tempmail, Tempmail.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
