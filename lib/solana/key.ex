defmodule Solana.Key do
  @moduledoc """
  functions for creating and checking Solana keys and keypairs
  """

  @type key :: Ed25519.key()
  @type keypair :: {key(), key()}

  @spec pair() :: keypair
  defdelegate pair, to: Ed25519, as: :generate_key_pair

  @spec decode(encoded :: binary) :: {:ok, key} | {:error, :invalid_key}
  def decode(encoded) when is_binary(encoded) do
    encoded
    |> Base58.decode()
    |> check()
  end

  def decode(_), do: {:error, :invalid_key}

  @spec decode!(encoded :: binary) :: key
  def decode!(encoded) when is_binary(encoded) do
    case decode(encoded) do
      {:ok, key} ->
        key

      {:error, :invalid_key} ->
        raise ArgumentError, "invalid public key input: #{encoded}"
    end
  end

  @spec check(binary) :: {:ok, key} | {:error, :invalid_key}
  def check(<<0>>), do: {:ok, <<0::32*8>>}
  def check(<<key::binary-32>>), do: {:ok, key}
  def check(_), do: {:error, :invalid_key}
end
