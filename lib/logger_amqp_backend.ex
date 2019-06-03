defmodule LoggerAmqpBackend do
  @compile if Mix.env == :test, do: :export_all
  use AMQP

  @behaviour :gen_event
  @default_state %{
    name: nil,
    format: nil,
    level: nil,
    metadata: nil,
    metadata_filter: nil,
    exchange: "",
    queue: "logs",
    amqp_channel: nil,
    amqp_conn: nil,
    amqp_url: "",
    routing_key: "",
    declare_queue: true,
    durable: true,
    queue_args: []
  }
  @default_format "{\"time\": \"$time $date\", \"level\": \"$level\", \"message\": \"$message\", \"metadata\":\"$metadata\"}"
  @reconnect_interval 10_000

  def init({__MODULE__, name}) do
    {:ok, configure(name, [])}
  end

  def handle_call({:configure, opts}, %{name: name} = state) do
    {:ok, :ok, configure(name, opts, state)}
  end



  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level, metadata_filter: metadata_filter} = state) do
    if (is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt) and metadata_matches?(md, metadata_filter) do
      log_event(level, msg, ts, md, state)
    else
      {:ok, state}
    end
  end

  def handle_event(:flush, state) do
    # We're not buffering anything so this is a no-op
    {:ok, state}
  end

  def handle_info({:connect, amqp_url}, %{routing_key: routing_key, declare_queue: declare, durable: durable, queue_args: queue_args} = s) do
    case Connection.open(amqp_url) do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        if declare do
          {:ok, _} = Queue.declare(chan, routing_key, durable: durable, arguments: queue_args)
        end
        {:ok, %{s | amqp_conn: conn, amqp_channel: chan}}

      {:error, _} ->
        #Logger.error("Failed to connect #{@host}. Reconnecting later...")
        # Retry later
        Process.send_after(self(), :connect, @reconnect_interval)
        {:ok, %{s | amqp_conn: nil}}
    end
  end

  def handle_info({:DOWN, _, :process, _pid, reason}, _) do
    # Stop GenServer. Will be restarted by Supervisor.
    {:stop, {:connection_lost, reason}, nil}
  end

  def handle_info(_, state) do
    {:ok, state}
  end

  # Helpers
  defp log_event(_level, _msg, _ts, _md, %{amqp_url: nil} = state) do
    {:ok, state}
  end

  defp log_event(level, msg, ts, md, %{amqp_channel: chan, exchange: exchange, routing_key: routing_key} = state)  do
    output = format_event(level, msg, ts, md, state)
    send_amqp(chan, exchange, routing_key, output)
    {:ok, state}
  end

  defp send_amqp(chan, exchange, routing_key, output) when is_list(output) do
    AMQP.Basic.publish(chan, exchange, routing_key, IO.chardata_to_string(output))
  end

  defp send_amqp(chan, exchange, routing_key, output) when is_binary(output) do
    AMQP.Basic.publish(chan, exchange, routing_key, output)
  end

  defp format_event(level, msg, ts, md, %{format: format, metadata: keys}) do
    Logger.Formatter.format(format, level, msg, ts, take_metadata(md, keys))
  end


  @doc false
  @spec metadata_matches?(Keyword.t, nil|Keyword.t) :: true|false
  def metadata_matches?(_md, nil), do: true
  def metadata_matches?(_md, []), do: true # all of the filter keys are present
  def metadata_matches?(md, [{key, val}|rest]) do
    case Keyword.fetch(md, key) do
      {:ok, ^val} ->
        metadata_matches?(md, rest)
      _ -> false #fail on first mismatch
    end
  end



  defp take_metadata(metadata, :all), do: metadata

  defp take_metadata(metadata, keys) do
    metadatas = Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error     -> acc
      end
    end)

    Enum.reverse(metadatas)
  end

  defp configure(name, opts) do
    configure(name, opts, @default_state)
  end

  defp configure(name, opts, state) do
    env = Application.get_env(:logger, name, [])
    opts = Keyword.merge(env, opts)
    Application.put_env(:logger, name, opts)

    level           = Keyword.get(opts, :level, :info)
    metadata        = Keyword.get(opts, :metadata, [])
    format_opts     = Keyword.get(opts, :format, @default_format)
    format          = Logger.Formatter.compile(format_opts)
    amqp_url        = Keyword.get(opts, :amqp_url)
    metadata_filter = Keyword.get(opts, :metadata_filter, nil)
    durable         = Keyword.get(opts, :durable, true)
    declare_queue   = Keyword.get(opts, :declare_queue, true)
    queue_args      = Keyword.get(opts, :queue_args, [])
    exchange        = Keyword.get(opts, :exchange, "")
    routing_key     = Keyword.get(opts, :routing_key, Atom.to_string(name))


    #send(self(), {:connect, amqp_url})
    {:ok, state} = handle_info({:connect, amqp_url}, state)

    #{:ok, _} = Queue.declare(chan, queue, durable: durable, arguments: args)
    #:ok = Queue.bind(chan, @queue, @exchange)

    %{state |
      name: name,
      amqp_url: amqp_url,
      format: format,
      level: level,
      metadata: metadata,
      metadata_filter: metadata_filter,
      exchange: exchange,
      routing_key: routing_key,
      durable: durable,
      declare_queue: declare_queue,
      queue_args: queue_args

    }
  end

end
