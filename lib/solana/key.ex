defmodule Solana.Key do
  @moduledoc """
  functions for creating and checking Solana keys and keypairs
  """

  @typedoc "Solana public or private key"
  @type t :: Ed25519.key()

  @typedoc "a public/private keypair"
  @type pair :: {t(), t()}

  @spec pair() :: pair
  @doc """
  Generates a public/private key pair in the format `{private_key, public_key}`
  """
  defdelegate pair, to: Ed25519, as: :generate_key_pair

  @doc """
  decodes a base58-encoded key and returns it in a tuple. If it fails, return
  an error tuple.
  """
  @spec decode(encoded :: binary) :: {:ok, t} | {:error, binary}
  def decode(encoded) when is_binary(encoded) do
    encoded |> B58.decode58!() |> check()
  end

  def decode(_), do: {:error, "invalid public key"}

  @doc """
  decodes a base58-encoded key and returns it. Throws an `ArgumentError` if it
  fails.
  """
  @spec decode!(encoded :: binary) :: t
  def decode!(encoded) when is_binary(encoded) do
    case decode(encoded) do
      {:ok, key} ->
        key

      {:error, _} ->
        raise ArgumentError, "invalid public key input: #{encoded}"
    end
  end

  @doc """
  Checks to see if a `t:Solana.Key.t` is valid.
  """
  @spec check(binary) :: {:ok, t} | {:error, binary}
  def check(<<key::binary-32>>), do: {:ok, key}
  def check(_), do: {:error, "invalid public key"}

  @doc """
  Derive a public key from another key, a seed, and a program ID. The program ID
  will also serve as the owner of the public key, giving it permission to write
  data to the account.
  """
  @spec with_seed(from :: t, seed :: binary, program_id :: t) ::
          {:ok, t} | {:error, binary}
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
  @spec derive_address(seeds :: [binary], program_id :: t) ::
          {:ok, t} | {:error, term}
  def derive_address(seeds, program_id) do
    with {:ok, program_id} <- check(program_id),
         true <- Enum.all?(seeds, &is_valid_seed?/1) do
      [seeds, program_id, "ProgramDerivedAddress"]
      |> hash()
      |> verify_off_curve()
    else
      err = {:error, _} -> err
      false -> {:error, :invalid_seeds}
    end
  end

  defp is_valid_seed?(seed) do
    (is_binary(seed) && byte_size(seed) <= 32) || seed in 0..255
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
  @spec find_address(seeds :: [binary], program_id :: t) ::
          {:ok, t, byte} | {:error, term}
  def find_address(seeds, program_id) do
    case check(program_id) do
      {:ok, program_id} ->
        Enum.reduce_while(255..1, {:error, :no_nonce}, fn nonce, acc ->
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
