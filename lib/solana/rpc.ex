defmodule Solana.RPC do
  require Logger

  alias Solana.RPC

  @doc """
  Creates an API client used to interact with Solana's JSON-RPC API
  """
  @spec client(map) :: Tesla.Client.t()
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
    Tesla.post(client, "/", Solana.RPC.Request.encode(requests))
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
    client
    |> RPC.send(requests)
    |> Enum.flat_map(fn
      {:ok, signature} ->
        [signature]
      {:error, %{"data" => %{"logs" => logs}, "message" => message}} ->
        [message | logs]
        |> Enum.join("\n")
        |> Logger.error()
        []
      {:error, error} ->
        Logger.error("error sending transaction: #{inspect error}")
        []
    end)
    |> case do
      [] ->
        :error
      signatures ->
        :ok = RPC.Tracker.start_tracking(tracker, signatures, request_opts)
        await_confirmations(signatures, timeout, [])
    end
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
