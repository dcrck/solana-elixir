defmodule Solana do
  @moduledoc """
  A library for interacting with the Solana blockchain
  """

  @type key :: Solana.Key.t()
  @type keypair :: Solana.Key.pair()

  defdelegate keypair(), to: Solana.Key, as: :pair

  def pubkey({_sk, pk}), do: Solana.Key.check(pk)
  defdelegate pubkey(encoded), to: Solana.Key, as: :decode

  def pubkey!(pair = {_sk, _pk}) do
    case pubkey(pair) do
      {:ok, key} -> key
      _ -> raise ArgumentError, "invalid keypair: #{inspect(pair)}"
    end
  end

  defdelegate pubkey!(encoded), to: Solana.Key, as: :decode!

  @doc """
  Creates or retrieves a client to interact with Solana's JSON RPC API.
  """
  @spec rpc_client(keyword) :: Tesla.Client.t()
  def rpc_client(config), do: Solana.RPC.client(Enum.into(config, %{}))

  # sysvars
  def rent(), do: pubkey!("SysvarRent111111111111111111111111111111111")
  def recent_blockhashes(), do: pubkey!("SysvarRecentB1ockHashes11111111111111111111")

  def lamports_per_sol(), do: 1_000_000_000
end
