defmodule Solana.RPC do
  @lamports_per_sol 1_000_000_000

  @doc """
  Creates an API client used to interact with Solana's JSON-RPC API
  """
  @spec client(map) :: Tesla.Client.t()
  def client(config) do
    middleware = [
      {Tesla.Middleware.BaseUrl, url(config)},
      Solana.RPC.Middleware,
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry, retry_opts(config)}
    ]

    Tesla.client(middleware, Map.get(config, :adapter, Tesla.Adapter.Httpc))
  end

  @doc """
  Sends the provided requests to the configured Solana RPC endpoint
  """
  @spec send(client :: Tesla.Client.t(), requests :: [Solana.RPC.Request.t()]) ::
          {:ok, term} | {:error, term}
  def send(client, requests), do: Tesla.post(client, "/", to_json_rpc(requests))

  defp to_json_rpc(requests) when is_list(requests) do
    requests
    |> Enum.with_index()
    |> Enum.map(&to_json_rpc/1)
  end

  defp to_json_rpc({{method, []}, id}) do
    %{jsonrpc: "2.0", id: id, method: method}
  end

  defp to_json_rpc({{method, params}, id}) do
    %{jsonrpc: "2.0", id: id, method: method, params: check_params(params)}
  end

  defp to_json_rpc({method, params}), do: to_json_rpc({{method, params}, 0})

  defp check_params([]), do: []
  defp check_params([map = %{} | rest]) when map_size(map) == 0, do: check_params(rest)
  defp check_params([elem | rest]), do: [elem | check_params(rest)]

  defp url(%{network: network}) when network in ["devnet", "mainnet-beta", "testnet"] do
    "https://api.#{network}.solana.com"
  end

  defp url(%{network: "localnet"}), do: "http://127.0.0.1:8899"
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
