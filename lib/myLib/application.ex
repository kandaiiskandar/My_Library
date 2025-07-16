defmodule MyLib.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MyLibWeb.Telemetry,
      MyLib.Repo,
      {DNSCluster, query: Application.get_env(:myLib, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MyLib.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: MyLib.Finch},
      # Start a worker by calling: MyLib.Worker.start_link(arg)
      # {MyLib.Worker, arg},
      # Start to serve requests, typically the last entry
      MyLibWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MyLib.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MyLibWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
