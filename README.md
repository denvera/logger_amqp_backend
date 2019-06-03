[![Build Status](https://travis-ci.org/denvera/logger_amqp_backend.svg?branch=master)](https://travis-ci.org/denvera/logger_amqp_backend)
[![Coverage Status](https://coveralls.io/repos/github/denvera/logger_amqp_backend/badge.svg?branch=master)](https://coveralls.io/github/denvera/logger_amqp_backend?branch=master)
[![hex.pm version](https://img.shields.io/hexpm/v/logger_amqp_backend.svg?style=flat)](https://hex.pm/packages/logger_file_backend)

# LoggerAmqpBackend

Elixir Logger backend to send logs to an AMQP broker (eg: RabbitMQ). Based largely on [logger_file_backend](https://github.com/onkel-dirtus/logger_file_backend).
## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `logger_amqp_backend` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:logger_amqp_backend, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/logger_amqp_backend](https://hexdocs.pm/logger_amqp_backend).

