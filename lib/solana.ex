defmodule Solana do
  @moduledoc """
  A library for interacting with the Solana JSON RPC API
  """
  @type key :: Ed25519.key()
  @type keypair :: {key(), key()}

  @spec keypair() :: keypair
  defdelegate keypair, to: Ed25519, as: :generate_key_pair

  @spec pubkey(encoded :: binary) :: {:ok, key} | {:error, :invalid_input}
  def pubkey(encoded) when is_binary(encoded) do
    encoded
    |> Base58.decode()
    |> check_pubkey()
  end

  def pubkey(_), do: {:error, :invalid_input}

  @spec pubkey!(encoded :: binary) :: key
  def pubkey!(encoded) when is_binary(encoded) do
    case pubkey(encoded) do
      {:ok, key} ->
        key

      {:error, :invalid_input} ->
        raise ArgumentError, "invalid public key input: #{encoded}"
    end
  end

  @spec check_pubkey(binary) :: {:ok, key} | {:error, :invalid_input}
  def check_pubkey(<<0>>), do: {:ok, <<0::32*8>>}
  def check_pubkey(<<key::binary-32>>), do: {:ok, key}
  def check_pubkey(_), do: {:error, :invalid_input}

  # sysvars
  def rent(), do: pubkey!("SysvarRent111111111111111111111111111111111")
  def recent_blockhashes(), do: pubkey!("SysvarRecentB1ockHashes11111111111111111111")
end
