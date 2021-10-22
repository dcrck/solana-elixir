defmodule Solana.Account do
  @moduledoc """
  Functions, types, and structures related to Solana
  [accounts](https://docs.solana.com/developing/programming-model/accounts).
  """

  @typedoc """
  All the information needed to encode an account in a transaction message.
  """
  @type t :: %__MODULE__{
          signer?: boolean(),
          writable?: boolean(),
          key: Solana.key() | nil
        }

  defstruct [
    :key,
    signer?: false,
    writable?: false
  ]
end
