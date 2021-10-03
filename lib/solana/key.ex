defmodule Solana.Key do
  @moduledoc """
  functions for creating and checking Solana keys and keypairs
  """

  @type key :: Ed25519.key()
  @type keypair :: {key(), key()}

  @spec pair() :: keypair
  defdelegate pair, to: Ed25519, as: :generate_key_pair

  @doc """
  decodes a base58-encoded key and returns it in a tuple. If it fails, return
  an error tuple.
  """
  @spec decode(encoded :: binary) :: {:ok, key} | {:error, :invalid_key}
  def decode(encoded) when is_binary(encoded) do
    encoded |> B58.decode58!() |> check()
  end

  def decode(_), do: {:error, :invalid_key}

  @doc """
  decodes a base58-encoded key and returns it. Throws an `ArgumentError` if it
  fails.
  """
  @spec decode!(encoded :: binary) :: key
  def decode!(encoded) when is_binary(encoded) do
    case decode(encoded) do
      {:ok, key} ->
        key

      {:error, :invalid_key} ->
        raise ArgumentError, "invalid public key input: #{encoded}"
    end
  end

  @doc """
  Checks to see if a key is valid.
  """
  @spec check(binary) :: {:ok, key} | {:error, :invalid_key}
  def check(<<key::binary-32>>), do: {:ok, key}
  def check(_), do: {:error, :invalid_key}
end
