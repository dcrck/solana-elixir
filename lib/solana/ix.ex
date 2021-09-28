defmodule Solana.Instruction do
  alias Solana.Account

  @type t :: %__MODULE__{
          program: Solana.key() | nil,
          accounts: [Account.t()],
          data: binary | nil
        }

  defstruct [
    :data,
    :program,
    accounts: []
  ]
end
