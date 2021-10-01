defmodule Solana.RPC do
  use Supervisor

  def start_link(config) do
    Supervisor.start_link(__MODULE__, config, name: __MODULE__)
  end

  def init(config) do
    Supervisor.init(children(config), strategy: :rest_for_one)
  end

  defp children(config) do
    [
      Solana.RPC.Client,
      Solana.RPC.RateLimiter,
      {Solana.RPC.Runner, config}
    ]
  end

  @doc """
  Creates an API client used to interact with Solana's JSON-RPC API
  """
  @spec client(map | pid()) :: Tesla.Client.t() | pid()
  def client(rpc) when is_pid(rpc) do
    rpc
    |> Supervisor.which_children()
    |> Enum.find(&(elem(&1, 0) == Solana.RPC.Client))
    |> case do
      nil -> nil
      child -> elem(child, 1)
    end
  end

  def client(config = %{}) do
    middleware = [
      {Tesla.Middleware.BaseUrl, url(config)},
      Solana.RPC.Middleware,
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry, retry_opts(config)}
    ]

    Tesla.client(middleware, Map.get(config, :adapter, Tesla.Adapter.Httpc))
  end

  @doc """
  Sends the provided requests to the configured Solana RPC endpoint.
  """
  def send(client, requests) do
    Solana.RPC.Client.send(client, requests)
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
