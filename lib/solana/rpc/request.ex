defmodule Solana.RPC.Request do
  @type t :: {String.t(), [String.t() | map]}

  @doc """
  Returns all information associated with the account of the provided Pubkey.
  For more information, see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#getaccountinfo].
  """
  @spec get_account_info(account :: Solana.key(), opts :: keyword) :: t
  def get_account_info(account, opts \\ []) do
    {"getAccountInfo", [Base58.encode(account), encode_opts(opts)]}
  end

  @doc """
  Returns the balance of the provided pubkey's account. For more information,
  see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#getbalance].
  """
  @spec get_balance(account :: Solana.key(), opts :: keyword) :: t
  def get_balance(account, opts \\ []) do
    {"getBalance", [Base58.encode(account), encode_opts(opts)]}
  end

  @doc """
  Returns identity and transaction information about a confirmed block in the
  ledger. For more information, see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#getblock].
  """
  @spec get_block(start_slot :: non_neg_integer, opts :: keyword) :: t
  def get_block(start_slot, opts \\ []) do
    {"getBlock", [start_slot, encode_opts(opts)]}
  end

  @doc """
  Returns a recent block hash from the ledger, and a fee schedule that can be
  used to compute the cost of submitting a transaction using it. For more
  information, see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#getrecentblockhash].
  """
  @spec get_recent_blockhash(opts :: keyword) :: t
  def get_recent_blockhash(opts \\ []) do
    {"getRecentBlockhash", [encode_opts(opts)]}
  end

  @doc """
  Returns minimum balance required to make account rent exempt. For more
  information, see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#getminimumbalanceforrentexemption].
  """
  @spec get_minimum_balance_for_rent_exemption(length :: non_neg_integer, opts :: keyword) :: t
  def get_minimum_balance_for_rent_exemption(length, opts \\ []) do
    {"getMinimumBalanceForRentExemption", [length, encode_opts(opts)]}
  end

  @doc """
  Submits a signed transaction to the cluster for processing. For more
  information, see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#sendtransaction].
  """
  @spec send_transaction(transaction :: Solana.Transaction.t(), opts :: keyword) :: t
  def send_transaction(tx = %Solana.Transaction{}, opts \\ []) do
    {:ok, tx_bin} = Solana.Transaction.to_binary(tx)
    {"sendTransaction", [Base.encode64(tx_bin), encode_opts(opts, %{"encoding" => "base64"})]}
  end

  @doc """
  Requests an airdrop of lamports to a Pubkey. For more information, see
  (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#requestairdrop].
  """
  @spec request_airdrop(account :: Solana.key(), lamports :: pos_integer, opts :: keyword) :: t
  def request_airdrop(account, sol, opts \\ []) do
    {"requestAirdrop", [Base58.encode(account), sol * @lamports_per_sol, encode_opts(opts)]}
  end

  @doc """
  Returns confirmed signatures for transactions involving an address backwards
  in time from the provided signature or most recent confirmed block. For more
  information, see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#getsignaturesforaddress].
  """
  @spec get_signatures_for_address(account :: Solana.key(), opts :: keyword) :: t
  def get_signatures_for_address(account, opts \\ []) do
    {"getSignaturesForAddress", [Base58.encode(account), encode_opts(opts)]}
  end

  @doc """
  Returns transaction details for a confirmed transaction. For more information,
  see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#gettransaction].
  """
  @spec get_transaction(signature :: Solana.key(), opts :: keyword) :: t
  def get_transaction(signature, opts \\ []) do
    {"getTransaction", [Base58.encode(signature), encode_opts(opts)]}
  end

  @doc """
  Returns the total supply of an SPL Token type. For more information, see
  (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#gettokensupply].
  """
  @spec get_token_supply(mint :: Solana.key(), opts :: keyword) :: t
  def get_token_supply(mint, opts \\ []) do
    {"getTokenSupply", [Base58.encode(mint), encode_opts(opts)]}
  end

  @doc """
  Returns the 20 largest accounts of a particular SPL Token type. For more
  information, see (the Solana docs)[https://docs.solana.com/developing/clients/jsonrpc-api#gettokenlargestaccounts].
  """
  @spec get_token_largest_accounts(mint :: Solana.key(), opts :: keyword) :: t
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
