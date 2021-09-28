defmodule Solana do
  @moduledoc """
  A library for interacting with the Solana JSON RPC API
  """
  @type key :: Ed25519.key()
  @type keypair :: {key(), key()}

  @spec keypair() :: keypair
  defdelegate keypair, to: Ed25519, as: :generate_key_pair
end
