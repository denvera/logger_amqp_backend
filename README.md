[![Build Status](https://travis-ci.org/denvera/logger_amqp_backend.svg?branch=master)](https://travis-ci.org/denvera/logger_amqp_backend)
[![Coverage Status](https://coveralls.io/repos/github/denvera/logger_amqp_backend/badge.png?branch=master)](https://coveralls.io/github/denvera/logger_amqp_backend?branch=master)
[![hex.pm version](https://img.shields.io/hexpm/v/logger_amqp_backend.svg?style=flat)](https://hex.pm/packages/logger_amqp_backend)

# LoggerAmqpBackend

Elixir Logger backend to send logs to an AMQP broker (eg: RabbitMQ). Based largely on [logger_file_backend](https://github.com/onkel-dirtus/logger_file_backend).
`LoggerAmqpBackend` is a custom backend for the elixir :logger application. The `:logger` application should be started prior to using this backend.

## Configuration

`LoggerAmqpBackend` is a custom backend for the elixir `:logger` application. As
such, it relies on the `:logger` application to start the relevant processes.
However, unlike the default `:console` backend, we may want to configure
multiple log files, each with different log levels formats, etc. Also, we want
`:logger` to be responsible for starting and stopping each of our logging
processes for us. Because of these considerations, there must be one `:logger`
backend configured for each log file we need. Each backend has a name like
`{LoggerAmqpBackend, id}`, where `id` is an atom.

For example, let's say we want to log error messages to
an AMQP broker (eg: RabbitMQ) `amqp://1.2.3.4/logs`. To do that, we will need to configure a backend.
Let's call it `{LoggerAmqpBackend, :error_log}`.

Our config.exs would have an entry similar to this:

```elixir
# tell logger to load a LoggerAmqpBackend processes
config :logger,
  backends: [{LoggerAmqpBackend, :amqp_error_log}]
```

With this configuration, the `:logger` application will start one `LoggerAmqpBackend`
named `{LoggerAmqpBackend, :amqp_error_log}`. We still need to set the parameters for the AMQP broker 
and log levels for the backend, though. To do that, we add another config
stanza. Together with the stanza above, we'll have something like this:

```elixir
# tell logger to load a LoggerAmqpBackend processes
config :logger,
  backends: [{LoggerAmqpBackend, :error_log}]

# configuration for the {LoggerAmqpBackend, :amqp_error_log} backend
config :logger, :amqp_error_log,
  amqp_url: "amqp://1.2.3.4/logs",
  routing_key: "logs_queue",  
  level: :error
```

Check out the examples below for runtime configuration and configuration for
multiple log files.

`LoggerAmqpBackend` supports the following configuration values:

* amqp_url - URL for AMQP (ie: RabbitMQ) broker. Eg: `amqp_url: "amqp://1.2.3.4/logs"`
* routing_key - Used as routing key when publishing, typically the queue name if using the default `""` exchange
* exchange - Usually the default (`""`) exchange, but can modified (Default: `""`)
* declare_queue - Set to `true` to declare the queue when starting up. (Default: `true`)
* durable - Set to `true` or `false` and used as the durable when declaring the queue. (Default: `true`)
* queue_args - Keyword list or arguments passed to `amqp` when declaring the queue. (Default: `[]`)
* level - the logging level for the backend
* format - the logging format for the backend (Default: `"{\"time\": \"$time $date\", \"level\": \"$level\", \"message\": \"$message\", \"metadata\":\"$metadata\"}"`)
* metadata - the metadata to include (Default: `[]`)
* metadata_filter - metadata terms which must be present in order to log (Default: `nil` (ie: no filter))


### Examples

#### Runtime configuration

```elixir
Logger.add_backend {LoggerAmqpBackend, :debug}
Logger.configure_backend {LoggerAmqpBackend, :debug},
  amqp_url: "amqp://1.2.3.4/logs",
  routing_key: "logs_queue",  
  format: ...,
  metadata: ...,
  metadata_filter: ...
```

#### Application config for multiple log files

```elixir
config :logger,
  backends: [{LoggerAmqpBackend, :info},
             {LoggerAmqpBackend, :error}]

config :logger, :info,
  amqp_url: "amqp://1.2.3.4/logs",
  routing_key: "info_logs",  
  level: :info

config :logger, :error,
  amqp_url: "amqp://1.2.3.4/logs",
  routing_key: "error_logs",  
  level: :error
```
#### Filtering specific metadata terms

This example only logs `:info` statements originating from the `:ui` OTP app; the `:application` metadata key is auto-populated by `Logger`.

```elixir
config :logger,
  backends: [{LoggerAmqpBackend, :ui}]

config :logger, :ui,
amqp_url: "amqp://1.2.3.4/logs",
  routing_key: "error_logs",  
  level: :info,
  metadata_filter: [application: :ui]
```

This example only writes log statements with a custom metadata key to the file.

```elixir
# in a config file:
config :logger,
  backends: [{LoggerAmqpBackend, :device_1}]

config :logger, :device_1
amqp_url: "amqp://1.2.3.4/logs",
  routing_key: "error_logs",  
  level: :debug,
  metadata_filter: [device: 1]

# Usage:
# anywhere in the code:
Logger.info("statement", device: 1)

# or, for a single process, e.g., a GenServer:
# in init/1:
Logger.metadata(device: 1)
# ^ sets device: 1 for all subsequent log statements from this process.

# Later, in other code (handle_cast/2, etc.)
Logger.info("statement") # <= already tagged with the device_1 metadata
```