defmodule SessionServerStore.Mixfile do
  use Mix.Project

  def project do
    [
      app: :session_server_store,
      build_embedded: Mix.env === :prod,
      deps: deps(),
      description: "A server-side session store",
      docs: docs(),
      elixir: "~> 1.4",
      name: "SessionServerStore",
      package: package(),
      start_permanent: Mix.env === :prod,
      version: "0.1.0",
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.15", only: :dev, runtime: false},
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme",
    ]
  end

  defp package do
    [
      licenses: ["BSD 2-Clause License"],
      links: %{
        "GitHub" => "https://github.com/endersstocker/session-server-store",
      },
      maintainers: ["Bryan Enders"],
    ]
  end

  def application, do: [mod: {SessionServerStore, []}]
end
