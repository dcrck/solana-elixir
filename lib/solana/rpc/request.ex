defmodule Solana.RPC.Request do
  @moduledoc """
  Functions for creating Solana JSON-RPC API requests.

  This client only implements the most common methods (see the function
  documentation below). If you need a method that's on the [full
  list](https://docs.solana.com/developing/clients/jsonrpc-api#json-rpc-api-reference)
  but is not implemented here, please open an issue or contact the maintainers.
  """

  @typedoc "JSON-RPC API request (pre-encoding)"
  @type t :: {String.t(), [String.t() | map]}

  @typedoc "JSON-RPC API request (JSON encoding)"
  @type json :: %{
          jsonrpc: String.t(),
          id: term,
          method: String.t(),
          params: list
        }

  @doc """
  Encodes a `t:Solana.RPC.Request.t` -- or a list of them -- in the [required
  format](https://docs.solana.com/developing/clients/jsonrpc-api#request-formatting).
  """
  @spec encode(requests :: [t]) :: [json]
  def encode(requests) when is_list(requests) do
    requests
    |> Enum.with_index()
    |> Enum.map(&to_json_rpc/1)
  end

  @spec encode(request :: t) :: json
  def encode(request), do: to_json_rpc({request, 0})

  defp to_json_rpc({{method, []}, id}) do
    %{jsonrpc: "2.0", id: id, method: method}
  end

  defp to_json_rpc({{method, params}, id}) do
    %{jsonrpc: "2.0", id: id, method: method, params: check_params(params)}
  end

  defp check_params([]), do: []
  defp check_params([map = %{} | rest]) when map_size(map) == 0, do: check_params(rest)
  defp check_params([elem | rest]), do: [elem | check_params(rest)]

  @doc """
  Returns all information associated with the account of the provided Pubkey.
  For more information, see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#getaccountinfo).
  """
  @spec get_account_info(account :: Solana.key(), opts :: keyword) :: t
  def get_account_info(account, opts \\ []) do
    {"getAccountInfo", [B58.encode58(account), encode_opts(opts, %{"encoding" => "base64"})]}
  end

  @doc """
  Returns the balance of the provided pubkey's account. For more information,
  see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#getbalance).
  """
  @spec get_balance(account :: Solana.key(), opts :: keyword) :: t
  def get_balance(account, opts \\ []) do
    {"getBalance", [B58.encode58(account), encode_opts(opts)]}
  end

  @doc """
  Returns identity and transaction information about a confirmed block in the
  ledger. For more information, see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#getblock).
  """
  @spec get_block(start_slot :: non_neg_integer, opts :: keyword) :: t
  def get_block(start_slot, opts \\ []) do
    {"getBlock", [start_slot, encode_opts(opts)]}
  end

  @doc """
  Returns a recent block hash from the ledger, and a fee schedule that can be
  used to compute the cost of submitting a transaction using it. For more
  information, see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#getrecentblockhash).
  """
  @spec get_recent_blockhash(opts :: keyword) :: t
  def get_recent_blockhash(opts \\ []) do
    {"getRecentBlockhash", [encode_opts(opts)]}
  end

  @doc """
  Returns minimum balance required to make account rent exempt. For more
  information, see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#getminimumbalanceforrentexemption).
  """
  @spec get_minimum_balance_for_rent_exemption(length :: non_neg_integer, opts :: keyword) :: t
  def get_minimum_balance_for_rent_exemption(length, opts \\ []) do
    {"getMinimumBalanceForRentExemption", [length, encode_opts(opts)]}
  end

  @doc """
  Submits a signed transaction to the cluster for processing. For more
  information, see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#sendtransaction).
  """
  @spec send_transaction(transaction :: Solana.Transaction.t(), opts :: keyword) :: t
  def send_transaction(tx = %Solana.Transaction{}, opts \\ []) do
    {:ok, tx_bin} = Solana.Transaction.to_binary(tx)
    opts = opts |> fix_tx_opts() |> encode_opts(%{"encoding" => "base64"})
    {"sendTransaction", [Base.encode64(tx_bin), opts]}
  end

  defp fix_tx_opts(opts) do
    opts
    |> Enum.map(fn
      {:commitment, commitment} -> {:preflight_commitment, commitment}
      other -> other
    end)
    |> Enum.into([])
  end

  @doc """
  Requests an airdrop of lamports to a Pubkey. For more information, see
  [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#requestairdrop).
  """
  @spec request_airdrop(account :: Solana.key(), lamports :: pos_integer, opts :: keyword) :: t
  def request_airdrop(account, sol, opts \\ []) do
    {"requestAirdrop",
     [B58.encode58(account), sol * Solana.lamports_per_sol(), encode_opts(opts)]}
  end

  @doc """
  Returns confirmed signatures for transactions involving an address backwards
  in time from the provided signature or most recent confirmed block. For more
  information, see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#getsignaturesforaddress).
  """
  @spec get_signatures_for_address(account :: Solana.key(), opts :: keyword) :: t
  def get_signatures_for_address(account, opts \\ []) do
    {"getSignaturesForAddress", [B58.encode58(account), encode_opts(opts)]}
  end

  @doc """
  Returns the statuses of a list of signatures. Unless the
  `searchTransactionHistory` configuration parameter is included, this method only
  searches the recent status cache of signatures, which retains statuses for all
  active slots plus `MAX_RECENT_BLOCKHASHES` rooted slots. For more information,
  see [the Solana
  docs](https://docs.solana.com/developing/clients/jsonrpc-api#getsignaturestatuses).
  """
  @spec get_signature_statuses(signatures :: [Solana.key()], opts :: keyword) :: t
  def get_signature_statuses(signatures, opts \\ []) do
    {"getSignatureStatuses", [Enum.map(signatures, &B58.encode58/1), encode_opts(opts)]}
  end

  @doc """
  Returns transaction details for a confirmed transaction. For more information,
  see [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#gettransaction).
  """
  @spec get_transaction(signature :: Solana.key(), opts :: keyword) :: t
  def get_transaction(signature, opts \\ []) do
    {"getTransaction", [B58.encode58(signature), encode_opts(opts)]}
  end

  @doc """
  Returns the total supply of an SPL Token type. For more information, see
  [the Solana docs](https://docs.solana.com/developing/clients/jsonrpc-api#gettokensupply).
  """
  @spec get_token_supply(mint :: Solana.key(), opts :: keyword) :: t
  def get_token_supply(mint, opts \\ []) do
    {"getTokenSupply", [B58.encode58(mint), encode_opts(opts)]}
  end

  @doc """
  Returns the 20 largest accounts of a particular SPL Token type. For more
  information, see [the Solana
  docs](https://docs.solana.com/developing/clients/jsonrpc-api#gettokenlargestaccounts).
  """
  @spec get_token_largest_accounts(mint :: Solana.key(), opts :: keyword) :: t
  def get_token_largest_accounts(mint, opts \\ []) do
    {"getTokenLargestAccounts", [B58.encode58(mint), encode_opts(opts)]}
  end

  defp encode_opts(opts, defaults \\ %{}) do
    Enum.into(opts, defaults, fn {k, v} -> {camelize(k), encode_value(v)} end)
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

  defp encode_value(v) do
    cond do
      :ok == elem(Solana.Key.check(v), 0) -> B58.encode58(v)
      :ok == elem(Solana.Transaction.check(v), 0) -> B58.encode58(v)
      true -> v
    end
  end
end
