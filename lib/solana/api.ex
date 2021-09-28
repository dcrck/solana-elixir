defmodule Solana.API do
  @doc """
  Creates an API client used to interact with Solana's JSON-RPC API
  """

  @type request :: {String.t(), [String.t() | map]}

  @spec client(keyword, keyword) :: Tesla.Client.t()
  def client(config, adapter_opts \\ []) do
    middleware = [
      {Tesla.Middleware.BaseUrl, url(Keyword.get(config, :network, "devnet"))},
      Solana.Middleware,
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Retry, retry_opts(config)}
    ]

    adapter = {Application.get_env(:tesla, :adapter, Tesla.Adapter.Httpc), adapter_opts}

    Tesla.client(middleware, adapter)
  end

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

  defp url(network) when network in ["devnet", "mainnet-beta", "testnet"] do
    "https://api.#{network}.solana.com"
  end

  defp url(other), do: other

  defp retry_opts(config) do
    [
      max_retries: 10,
      max_delay: 4_000,
      should_retry: fn
        {:ok, %{status: status}} when status in 500..599 -> true
        {:ok, _} -> false
        {:error, _} -> true
      end
    ]
    |> Keyword.merge(Keyword.get(config, :retry_options, []))
  end

  # API methods
  @spec get_account_info(account :: Solana.key(), opts :: keyword) :: request
  def get_account_info(account, opts \\ []) do
    {"getAccountInfo", [Base58.encode(account), encode_opts(opts)]}
  end

  @spec get_balance(account :: Solana.key(), opts :: keyword) :: request
  def get_balance(account, opts \\ []) do
    {"getBalance", [Base58.encode(account), encode_opts(opts)]}
  end

  @spec get_block(start_slot :: non_neg_integer, opts :: keyword) :: request
  def get_block(start_slot, opts \\ []) do
    {"getBlock", [start_slot, encode_opts(opts)]}
  end

  @spec get_recent_blockhash(opts :: keyword) :: request
  def get_recent_blockhash(opts \\ []) do
    {"getRecentBlockhash", [encode_opts(opts)]}
  end

  @spec get_minimum_balance_for_rent_exemption(length :: non_neg_integer, opts :: keyword) ::
          request
  def get_minimum_balance_for_rent_exemption(length, opts \\ []) do
    {"getMinimumBalanceForRentExemption", [length, encode_opts(opts)]}
  end

  @spec get_account_info(transaction :: Solana.Transaction.t(), opts :: keyword) :: request
  def send_transaction(tx, opts \\ []) do
    {"sendTransaction", [Base.encode64(tx), encode_opts(opts, %{"encoding" => "base64"})]}
  end

  @spec request_airdrop(account :: Solana.key(), lamports :: non_neg_integer, opts :: keyword) ::
          request
  def request_airdrop(account, lamports, opts \\ []) do
    {"requestAirdrop", [Base58.encode(account), lamports, encode_opts(opts)]}
  end

  @spec get_signatures_for_address(account :: Solana.key(), opts :: keyword) :: request
  def get_signatures_for_address(account, opts \\ []) do
    {"getSignaturesForAddress", [Base58.encode(account), encode_opts(opts)]}
  end

  @spec get_transaction(signature :: Solana.key(), opts :: keyword) :: request
  def get_transaction(signature, opts \\ []) do
    {"getTransaction", [Base58.encode(signature), encode_opts(opts)]}
  end

  @spec get_token_supply(mint :: Solana.key(), opts :: keyword) :: request
  def get_token_supply(mint, opts \\ []) do
    {"getTokenSupply", [Base58.encode(mint), encode_opts(opts)]}
  end

  @spec get_token_largest_accounts(mint :: Solana.key(), opts :: keyword) :: request
  def get_token_largest_accounts(mint, opts \\ []) do
    {"getTokenLargestAccounts", [Base58.encode(mint), encode_opts(opts)]}
  end

  defp encode_opts(opts, defaults \\ %{}) do
    Enum.into(opts, defaults, fn {k, v} -> {camelize(k), v} end)
  end

  defp camelize(word) do
    case Regex.split(~r/(?:^|[-_])|(?=[A-Z])/, to_string(word)) do
      words ->
        words
        |> Enum.filter(&(&1 != ""))
        |> camelize_list(:lower)
        |> Enum.join()
    end
  end

  defp camelize_list([], _), do: []

  defp camelize_list([h | tail], :lower) do
    [String.downcase(h)] ++ camelize_list(tail, :upper)
  end

  defp camelize_list([h | tail], :upper) do
    [String.capitalize(h)] ++ camelize_list(tail, :upper)
  end
end
