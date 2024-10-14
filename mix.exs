defmodule Dht.MixProject do
  use Mix.Project

  def project do
    [
      app: :dhtex,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Dht.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:uuid, "~>1.1"},
      {:cowboy, "~>2.12"},
      {:plug_cowboy, "~>2.7"},
      {:jason, "~>1.4"},
      {:credo, "~>1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~>1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
