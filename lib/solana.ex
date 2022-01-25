defmodule Solana do
  @moduledoc """
  A library for interacting with the Solana blockchain.
  """

  @typedoc "See `t:Solana.Key.t/0`"
  @type key :: Solana.Key.t()

  @typedoc "See `t:Solana.Key.pair/0`"
  @type keypair :: Solana.Key.pair()

  @doc """
  See `Solana.Key.pair/0`
  """
  defdelegate keypair(), to: Solana.Key, as: :pair

  @doc """
  Decodes or extracts a `t:Solana.Key.t/0` from a Base58-encoded string or a
  `t:Solana.Key.pair/0`.

  Returns `{:ok, key}` if the key is valid, or an error tuple if it's not.
  """
  def pubkey(pair_or_encoded)
  def pubkey({_sk, pk}), do: Solana.Key.check(pk)
  defdelegate pubkey(encoded), to: Solana.Key, as: :decode

  @doc """
  Decodes or extracts a `t:Solana.Key.t/0` from a Base58-encoded string or a
  `t:Solana.Key.pair/0`.

  Throws an `ArgumentError` if it fails to retrieve the public key.
  """
  def pubkey!(pair_or_encoded)

  def pubkey!(pair = {_sk, _pk}) do
    case pubkey(pair) do
      {:ok, key} -> key
      _ -> raise ArgumentError, "invalid keypair: #{inspect(pair)}"
    end
  end

  defdelegate pubkey!(encoded), to: Solana.Key, as: :decode!

  @doc """
  The public key for the [Rent system
  variable](https://docs.solana.com/developing/runtime-facilities/sysvars#rent).
  """
  def rent(), do: pubkey!("SysvarRent111111111111111111111111111111111")

  @doc """
  The public key for the [RecentBlockhashes system
  variable](https://docs.solana.com/developing/runtime-facilities/sysvars#recentblockhashes)
  """
  def recent_blockhashes(), do: pubkey!("SysvarRecentB1ockHashes11111111111111111111")

  @doc """
  The public key for the [Clock system
  variable](https://docs.solana.com/developing/runtime-facilities/sysvars#clock)
  """
  def clock(), do: pubkey!("SysvarC1ock11111111111111111111111111111111")

  @doc """
  The public key for the [BPF Loader
  program](https://docs.solana.com/developing/runtime-facilities/programs#bpf-loader)
  """
  def bpf_loader(), do: pubkey!("BPFLoaderUpgradeab1e11111111111111111111111")

  @doc false
  def lamports_per_sol(), do: 1_000_000_000
end
