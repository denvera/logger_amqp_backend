defmodule LoggerAmqpBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_amqp_backend,
      version: "0.1.1",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
      deps: deps()
    ]
  end

  def application do
    [
      applications: []
    ]
  end

  defp deps do
    [
      {:amqp, "~> 1.2"},
      {:mock, "~> 0.3.0", only: :test},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end
end
