defmodule Dht.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :duplicate, name: Dht.Registry},
      {Plug.Cowboy, scheme: :http, plug: Dht.Api.Router, options: [port: 4000]}
    ]

    opts = [strategy: :one_for_one, name: Dht.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
