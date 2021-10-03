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

  @spec with_seed(from :: key, seed :: binary, program_id :: key) ::
          {:ok, key} | {:error, :invalid_key}
  def with_seed(from, seed, program_id) do
    with {:ok, from} <- check(from),
         {:ok, program_id} <- check(program_id) do
      [from, seed, program_id]
      |> hash()
      |> check()
    else
      err -> err
    end
  end

  @doc """
  Derives a program address from seeds and a program ID.
  """
  @spec derive_address(seeds :: [binary], program_id :: key) ::
          {:ok, key} | {:error, term}
  def derive_address(seeds, program_id) do
    with {:ok, program_id} <- check(program_id),
         true <- Enum.all?(seeds, &(is_binary(&1) && byte_size(&1) <= 32)) do
      [seeds, program_id, "ProgramDerivedAddress"]
      |> hash()
      |> verify_off_curve()
    else
      err = {:error, _} -> err
      false -> {:error, :invalid_seeds}
    end
  end

  defp hash(data), do: :crypto.hash(:sha256, data)

  defp verify_off_curve(hash) do
    if Ed25519.on_curve?(hash), do: {:error, :invalid_seeds}, else: {:ok, hash}
  end

  @doc """
  Finds a valid program address.

  Valid addresses must fall off the ed25519 curve; generate a series of nonces,
  then combine each one with the given seeds and program ID until a valid
  address is found. If we can't find one, return an error tuple.
  """
  @spec find_address(seeds :: [binary], program_id :: key) ::
          {:ok, key, byte} | {:error, term}
  def find_address(seeds, program_id) do
    case check(program_id) do
      {:ok, program_id} ->
        Enum.reduce_while(255..1, {:cont, {:error, :no_nonce}}, fn nonce, acc ->
          case derive_address(List.flatten([seeds, nonce]), program_id) do
            {:ok, address} -> {:halt, {:ok, address, nonce}}
            _err -> {:cont, acc}
          end
        end)

      error ->
        error
    end
  end
end
