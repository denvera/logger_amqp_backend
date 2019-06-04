defmodule LoggerAmqpBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_amqp_backend,
      version: "0.1.3",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
      deps: deps(),
      description: description(),
      package: package(),
      name: "logger_amqp_backend",
      source_url: "https://github.com/denvera/logger_amqp_backend"
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
      {:ex_doc, "~> 0.19", only: :dev, runtime: false},
      {:mock, "~> 0.3.0", only: :test},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp description() do
    "Elixir Logger backend to send logs to an AMQP broker (eg: RabbitMQ)"
  end
  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/denvera/logger_amqp_backend"}
    ]
  end
end
