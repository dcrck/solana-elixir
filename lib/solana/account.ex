defmodule Solana.Account do
  @moduledoc false
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
