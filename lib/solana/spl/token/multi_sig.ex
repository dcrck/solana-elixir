defmodule Solana.SPL.Token.MultiSig do
  @moduledoc """
  Functions for dealing with multi-signature accounts.

  Multi-signature accounts can used in place of any single owner/delegate
  accounts in any token instruction that require an owner/delegate to be
  present. The variant field represents the number of signers (M)
  required to validate this multisignature account.
  """

  alias Solana.{Instruction, Account, SPL.Token, SystemProgram}
  import Solana.Helpers

  @type t :: %__MODULE__{
          m: byte,
          n: byte,
          initialized?: boolean,
          signers: [Solana.key()]
        }

  defstruct m: 1,
            n: 1,
            initialized?: false,
            signers: []

  def byte_size(), do: 355

  @doc """
  Creates the instructions to initialize a multisignature account with N
  provided signers. **These instructions must be included in the same
  Transaction.**
  """
  def init(opts) do
    schema = [
      payer: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account that will pay for the multisig creation"
      ],
      balance: [
        type: :non_neg_integer,
        required: true,
        doc: "The lamport balance the multisig account should have"
      ],
      signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        required: true,
        doc: "The full set of signers"
      ],
      m: [
        type: {:in, 1..11},
        required: true,
        doc: "number of required signatures"
      ],
      new: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "public key for the new multisig account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        [
          SystemProgram.create_account(%{
            lamports: params.balance,
            space: byte_size(),
            from: params.payer,
            new: params.new,
            program_id: Token.id()
          }),
          initialize_ix(params)
        ]

      error ->
        error
    end
  end

  defp initialize_ix(params) do
    %Instruction{
      program: Token.id(),
      accounts: [
        %Account{key: params.new, writable?: true},
        %Account{key: Solana.rent()}
        | Enum.map(params.signers, &%Account{key: &1})
      ],
      data: Instruction.encode_data([2, params.m])
    }
  end
end
