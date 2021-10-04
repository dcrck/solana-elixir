defmodule Solana do
  @moduledoc """
  A library for interacting with the Solana blockchain
  """

  @type key :: Solana.Key.t()
  @type keypair :: Solana.Key.pair()

  defdelegate keypair(), to: Solana.Key, as: :pair
  defdelegate pubkey(encoded), to: Solana.Key, as: :decode
  defdelegate pubkey!(encoded), to: Solana.Key, as: :decode!

  @doc """
  Creates or retrieves a client to interact with Solana's JSON RPC API.
  """
  @spec rpc_client(keyword | pid) :: Tesla.Client.t() | pid
  def rpc_client(rpc) when is_pid(rpc), do: Solana.RPC.client(rpc)
  def rpc_client(config), do: Solana.RPC.client(Enum.into(config, %{}))

  # sysvars
  def rent(), do: pubkey!("SysvarRent111111111111111111111111111111111")
  def recent_blockhashes(), do: pubkey!("SysvarRecentB1ockHashes11111111111111111111")
end
