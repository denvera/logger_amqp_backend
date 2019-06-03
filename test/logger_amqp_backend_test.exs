defmodule LoggerAmqpBackendTest do
  use ExUnit.Case, async: false

  import Mock

  require Logger

  @backend {LoggerAmqpBackend, :test}

  doctest LoggerAmqpBackend

  setup_with_mocks([
    {AMQP.Connection, [], [open: &MockConn.open/1]},
    {AMQP.Channel, [], [open: fn _ -> {:ok, "test chan"} end]},
    {AMQP.Queue, [], [declare: fn _, _, _ -> {:ok, "queue"} end]},
    #{AMQP.Basic, [], [publish: fn _, _, _, msg ->
    #  IO.puts "Publish: #{msg}"
    #  {:ok,nil}
    #end]}
    ]) do
      IO.puts "Add backend"
      case Logger.add_backend @backend do
        {:ok, _} ->
          config [amqp_url: "amqp://some.url:2134/vhost", level: :debug]
        _ ->
          nil
      end
    {:ok, %{pid: self()}}
  end

  test_with_mock "log a message", context, AMQP.Basic, [], [publish: fn _, _, _, msg ->
    IO.puts "Publish: #{msg}"
    send(context[:pid], :test_log)
    {:ok,nil}
  end] do
    config [amqp_url: "amqp://some.url:2134/vhost", level: :debug, metadata_filter: nil]
    Logger.debug "Log a message"
    assert_receive(:test_log, 500)
  end

  test_with_mock "log with metadata", context, AMQP.Basic, [], [publish: fn _, _, _, msg ->
    IO.puts "Publish: #{msg} send to #{inspect(context[:pid])}"
    send(context[:pid], :test_meta)
    {:ok,nil}
  end] do
    config [amqp_url: "amqp://some.url:2134/vhost", level: :debug, metadata: [:test_meta], metadata_filter: nil]
    IO.puts "My PID: #{inspect(self())}"
    Logger.info "Log a message with metadata", [test_meta: :some_metadata]
    assert_receive(:test_meta, 500)
  end

  test_with_mock "log with metadata filter", context, AMQP.Basic, [], [publish: fn _, _, _, msg ->
    IO.puts "Publish: #{msg} send to #{inspect(context[:pid])}"
    send(context[:pid], :test_meta_filter)
    {:ok,nil}
  end] do
    config([amqp_url: "amqp://some.url:2134/vhost", level: :debug, metadata_filter: [test_meta: true]])
    IO.puts "My PID: #{inspect(self())}"
    Logger.info "Log a message with metadata filter", [test_meta: true]
    assert_receive(:test_meta_filter, 500)
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end

end

defmodule MockConn do
  defstruct [:pid]

  def open(_) do
    pid = spawn(fn ->
      receive do
        :exit ->
          IO.puts("Shutdown MockConn")
      end
    end
      )
    {:ok, %MockConn{pid: pid}}
  end
end
