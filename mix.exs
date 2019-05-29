defmodule LoggerAmqpBackend.MixProject do
  use Mix.Project

  def project do
    [
      app: :logger_amqp_backend,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger],
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:amqp, "~> 1.2"},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end
end
