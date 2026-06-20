defmodule WindotProducts.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WindotProductsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:windot_products, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WindotProducts.PubSub},
      # Start a worker by calling: WindotProducts.Worker.start_link(arg)
      # {WindotProducts.Worker, arg},
      # Start to serve requests, typically the last entry
      WindotProductsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WindotProducts.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WindotProductsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
