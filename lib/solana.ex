defmodule Solana do
  @moduledoc """
  A library for interacting with the Solana blockchain
  """

  @typedoc "See `t:Solana.Key.t`"
  @type key :: Solana.Key.t()

  @typedoc "See `t:Solana.Key.pair`"
  @type keypair :: Solana.Key.pair()

  @doc """
  See `Solana.Key.pair/0`
  """
  defdelegate keypair(), to: Solana.Key, as: :pair

  @doc """
  Decodes or extracts a `t:Solana.Key.t` from a Base58-encoded string or a
  `t:Solana.Key.pair`. Returns `{:ok, key}` if the key is valid, or an error
  tuple if it's not.
  """
  def pubkey({_sk, pk}), do: Solana.Key.check(pk)
  defdelegate pubkey(encoded), to: Solana.Key, as: :decode

  @doc """
  Decodes or extracts a `t:Solana.Key.t` from a Base58-encoded string or a
  `t:Solana.Key.pair`. Throws an `ArgumentError` if it fails to retrieve the
  public key.
  """
  def pubkey!(pair = {_sk, _pk}) do
    case pubkey(pair) do
      {:ok, key} -> key
      _ -> raise ArgumentError, "invalid keypair: #{inspect(pair)}"
    end
  end

  defdelegate pubkey!(encoded), to: Solana.Key, as: :decode!

  @doc """
  Calls `Solana.RPC.client/1` with the list of `options` turned into a map.
  """
  @spec rpc_client(options :: keyword) :: Tesla.Client.t()
  def rpc_client(config), do: Solana.RPC.client(Enum.into(config, %{}))

  @doc """
  The public key for the Rent system variable. See the
  [docs](https://docs.solana.com/developing/runtime-facilities/sysvars#rent) for
  more information.
  """
  def rent(), do: pubkey!("SysvarRent111111111111111111111111111111111")

  @doc """
  The public key for the RecentBlockhashes system varaible. See the
  [docs](https://docs.solana.com/developing/runtime-facilities/sysvars#recentblockhashes)
  for more information.
  """
  def recent_blockhashes(), do: pubkey!("SysvarRecentB1ockHashes11111111111111111111")

  @doc false
  def lamports_per_sol(), do: 1_000_000_000
end
