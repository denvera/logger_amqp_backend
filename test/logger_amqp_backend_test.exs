defmodule LoggerAmqpBackendTest do
  use ExUnit.Case, async: false
  import Mock
  require Logger

  @backend {LoggerAmqpBackend, :test}

  doctest LoggerAmqpBackend

  setup_with_mocks([
    {AMQP.Connection, [], [open: &MockConn.open/1]},
    {AMQP.Channel, [], [open: fn _ -> {:ok, "test chan"} end]},
    {AMQP.Queue, [], [declare: fn _, _, _ -> {:ok, "queue"} end]}
  ]) do
    IO.puts("Add backend")

    case Logger.add_backend(@backend) do
      {:ok, _} ->
        config(amqp_url: "amqp://some.url:2134/vhost", level: :debug)

      _ ->
        nil
    end

    {:ok, %{pid: self()}}
  end

  test_with_mock "log a message", context, AMQP.Basic, [],
    publish: fn _, _, _, msg ->
      IO.puts("Publish: #{msg}")
      send(context[:pid], :test_log)
      {:ok, nil}
    end do
    config(amqp_url: "amqp://some.url:2134/vhost", level: :debug, metadata_filter: nil)
    Logger.debug("Log a message")
    Logger.flush()
    assert_receive(:test_log, 500)
  end

  test_with_mock "log with metadata", context, AMQP.Basic, [],
    publish: fn _, _, _, msg ->
      IO.puts("Publish: #{msg} send to #{inspect(context[:pid])}")
      send(context[:pid], :test_meta)
      {:ok, nil}
    end do
    config(
      amqp_url: "amqp://some.url:2134/vhost",
      level: :debug,
      metadata: [:test_meta],
      metadata_filter: nil
    )

    IO.puts("My PID: #{inspect(self())}")
    Logger.info("Log a message with metadata", test_meta: :some_metadata)
    assert_receive(:test_meta, 500)
  end

  test_with_mock "log with metadata filter", context, AMQP.Basic, [],
    publish: fn _, _, _, msg ->
      IO.puts("Publish: #{msg} send to #{inspect(context[:pid])}")
      send(context[:pid], :test_meta_filter)
      {:ok, nil}
    end do
    config(
      amqp_url: "amqp://some.url:2134/vhost",
      level: :debug,
      metadata_filter: [test_meta: true]
    )

    IO.puts("My PID: #{inspect(self())}")
    Logger.info("Log a message with metadata filter", test_meta: true)
    assert_receive(:test_meta_filter, 500)
  end

  test_with_mock "log with metadata filter not matching", context, AMQP.Basic, [],
    publish: fn _, _, _, msg ->
      IO.puts("Publish: #{msg} send to #{inspect(context[:pid])}")
      send(context[:pid], :test_meta_filter)
      {:ok, nil}
    end do
    config(
      amqp_url: "amqp://some.url:2134/vhost",
      level: :debug,
      metadata: [:test_meta],
      metadata_filter: [test_meta: true]
    )

    IO.puts("My PID: #{inspect(self())}")
    Logger.info("Log a message with metadata filter", something_else: :a_value)
    refute_receive(:test_meta_filter, 100)
  end

  test_with_mock "log a message using json formatter", context, AMQP.Basic, [],
    publish: fn _, _, _, msg ->
      IO.puts("Publish: #{msg} send to #{inspect(context[:pid])}")
      send(context[:pid], :test_log_with_json)
      {:ok, nil}
    end do
    config(
      amqp_url: "amqp://some.url:2134/vhost",
      level: :debug,
      metadata_filter: nil,
      format: :json
    )

    Logger.debug("Log a message using json formatter")
    assert_receive(:test_log_with_json, 500)
  end

  test_with_mock "connection failure", _context, AMQP.Connection, [],
    open: fn _ ->
      {:error, nil}
    end do
    s = %{
      amqp_url: "ignored",
      routing_key: nil,
      declare_queue: nil,
      durable: nil,
      queue_args: [],
      amqp_conn: "notnil",
      buffered: []
    }

    assert LoggerAmqpBackend.handle_info(:connect, s) == {:ok, %{s | amqp_conn: nil}}
  end

  test_with_mock "handle a nil url", context, AMQP.Basic, [],
    publish: fn _, _, _, msg ->
      send(context[:pid], :a_nil_url)
      {:ok, nil}
    end do
    config(amqp_url: nil, level: :debug, metadata_filter: nil, format: :json)
    Logger.debug("Log a message using json formatter")
    refute_receive(:a_nil_url, 500)
  end

  test "specifying :all for metadata just includes all metadata" do
    assert LoggerAmqpBackend.take_metadata([all: :data], :all) == [all: :data]
  end

  test "receiving a DOWN message stops process" do
    assert LoggerAmqpBackend.handle_info({:DOWN, :ignored, :process, :pid, "reason"}, :state) ==
             {:stop, {:connection_lost, "reason"}, nil}
  end

  test_with_mock "publishing a charlist or a binary works", context, AMQP.Basic, [],
    publish: fn _, _, _, msg ->
      IO.puts("Publish: #{inspect(msg)} send to #{inspect(context[:pid])}")
      send(context[:pid], :test_binary_publish)
      {:ok, nil}
    end do
    LoggerAmqpBackend.send_amqp(nil, nil, nil, ['A', ' ', 'l', 'i', 's', 't'])
    LoggerAmqpBackend.send_amqp(nil, nil, nil, "A string")
    assert_receive(:test_binary_publish, 500)
  end

  defp config(opts) do
    Logger.configure_backend(@backend, opts)
  end
end

defmodule MockConn do
  defstruct [:pid]

  def open(_) do
    pid =
      spawn(fn ->
        receive do
          :exit ->
            IO.puts("Shutdown MockConn")
        end
      end)

    {:ok, %MockConn{pid: pid}}
  end
end
