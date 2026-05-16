defmodule Tempmail.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TempmailWeb.Telemetry,
      Tempmail.Repo,
      {Redix, redis_options()},
      {DNSCluster, query: Application.get_env(:tempmail, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Tempmail.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Tempmail.Finch},
      # Start a worker by calling: Tempmail.Worker.start_link(arg)
      # {Tempmail.Worker, arg},
      # Start to serve requests, typically the last entry
      TempmailWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tempmail.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TempmailWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp redis_options do
    uri = Application.get_env(:tempmail, :redis_url, "redis://localhost:6379") |> URI.parse()
    userinfo = uri.userinfo || ""
    password = userinfo |> String.split(":", parts: 2) |> List.last()
    database = uri.path && uri.path |> String.trim_leading("/") |> parse_database()

    [
      name: Tempmail.Redis,
      host: uri.host || "localhost",
      port: uri.port || 6379
    ]
    |> maybe_put(:password, if(password == "", do: nil, else: password))
    |> maybe_put(:database, database)
  end

  defp parse_database(""), do: nil

  defp parse_database(value) do
    case Integer.parse(value) do
      {database, _} -> database
      :error -> nil
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
