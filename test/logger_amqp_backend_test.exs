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
    {AMQP.Basic, [], [publish: fn _, _, _, msg ->
      IO.puts "Publish: #{msg}"
      {:ok,nil}
    end]}
    ]) do
      {:ok, _} = Logger.add_backend @backend
      ExUnit.Callbacks.on_exit(fn ->
        :ok = Logger.remove_backend(@backend)
      end)
      config [amqp_url: "amqp://some.url:2134/vhost", level: :debug]
    :ok
  end

  test "log a message" do
    Logger.debug "This is a test message"
    assert_called AMQP.Basic.publish(:_, :_, :_, :_)
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
