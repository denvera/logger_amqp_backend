defmodule LoggerAmqpBackendTest do
  use ExUnit.Case, async: false

  import Mock

  require Logger

  @backend {LoggerAmqpBackend, :test}
  Logger.add_backend @backend

  doctest LoggerAmqpBackend

  setup_with_mocks([
    {AMQP.Connection, [], [open: fn _ -> {:ok, "test conn"} end]},
    {AMQP.Channel, [], [open: fn _ -> {:ok, "test chan"} end]},
    {AMQP.Basic, [], [publish: fn _, _, _, msg ->
      IO.puts "Publish: #{msg}"
      {:ok,nil}
    end]}
    ]) do
      #IO.puts("Log a message")
      config [amqp_url: "amqp://some.url:2134/vhost", level: :debug]
    :ok
  end

  test "log a message" do
    IO.puts("Log a message")
    Logger.debug "This is a test message"
    assert_called AMQP.Basic.publish(:_, :_, :_, :_)
  end
  test "test" do
    assert true == true
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end

end
