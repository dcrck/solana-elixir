defmodule Solana.RPC do
  use Supervisor
  require Logger

  alias Solana.RPC

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    Supervisor.init(children(config), strategy: :rest_for_one)
  end

  defp children(config) do
    [
      RPC.Client,
      RPC.RateLimiter,
      {RPC.Runner, config}
    ]
  end

  @doc """
  Creates an API client used to interact with Solana's JSON-RPC API
  """
  @spec client(map | pid()) :: Tesla.Client.t() | pid()
  def client(rpc) when is_pid(rpc) do
    rpc
    |> Supervisor.which_children()
    |> Enum.find(&(elem(&1, 0) == RPC.Client))
    |> case do
      nil -> nil
      child -> elem(child, 1)
    end
  end

  def client(config = %{}) do
    middleware = [
      {Tesla.Middleware.BaseUrl, url(config)},
      RPC.Middleware,
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry, retry_opts(config)}
    ]

    Tesla.client(middleware, Map.get(config, :adapter, Tesla.Adapter.Httpc))
  end

  @doc """
  Sends the provided requests to the configured Solana RPC endpoint.
  """
  def send(client, requests) do
    RPC.Client.send(client, requests)
  end

  @doc """
  Sends the provided transactions to the configured RPC endpoint, then confirms them.
  Returns a tuple containing all the transactions in the order they were confirmed, OR
  an error tuple containing the list of all the transactions that were confirmed
  before the error occurred.
  """
  @spec send_and_confirm(any, pid, [Solana.Transaction.t()] | Solana.Transaction.t, keyword) :: {:ok, [binary]} | {:error, :timeout, [binary]}
  def send_and_confirm(client, tracker, txs, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5_000)
    request_opts = Keyword.take(opts, [:commitment])
    requests = Enum.map(List.wrap(txs), &RPC.Request.send_transaction(&1, request_opts))
    signatures =
      client
      |> RPC.send(requests)
      |> Enum.flat_map(fn
        {:ok, signature} ->
          [signature]
        {:error, error} ->
          Logger.error("error sending transaction: #{inspect error}")
          []
      end)
    :ok = RPC.Tracker.start_tracking(tracker, signatures, request_opts)

    await_confirmations(signatures, timeout, [])
  end

  defp await_confirmations([], _, confirmed), do: {:ok, confirmed}

  defp await_confirmations(signatures, timeout, done) do
    receive do
      {:ok, confirmed} ->
        MapSet.new(signatures)
        |> MapSet.difference(MapSet.new(confirmed))
        |> MapSet.to_list()
        |> await_confirmations(timeout, List.flatten([done, confirmed]))
    after
      timeout -> {:error, :timeout, done}
    end
  end

  defp url(%{network: network}) when network in ["devnet", "mainnet-beta", "testnet"] do
    "https://api.#{network}.solana.com"
  end

  defp url(%{network: "localhost"}), do: "http://127.0.0.1:8899"
  defp url(%{network: other}), do: other

  defp retry_opts(config) do
    Keyword.merge(retry_defaults(), Map.get(config, :retry_options, []))
  end

  defp retry_defaults() do
    [max_retries: 10, max_delay: 4_000, should_retry: &should_retry?/1]
  end

  defp should_retry?({:ok, %{status: status}}) when status in 500..599, do: true
  defp should_retry?({:ok, _}), do: false
  defp should_retry?({:error, _}), do: true
end
