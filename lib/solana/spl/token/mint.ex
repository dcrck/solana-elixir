defmodule Solana.SPL.Token.Mint do
  alias Solana.{Instruction, Account, SPL.Token, SystemProgram}
  import Solana.Helpers

  @type t :: %__MODULE__{
          authority: Solana.key() | nil,
          supply: non_neg_integer,
          decimals: byte,
          initialized?: boolean,
          freeze_authority: Solana.key() | nil,
          key: Solana.key()
        }

  defstruct [
    :authority,
    :supply,
    :freeze_authority,
    :key,
    decimals: 0,
    initialized?: false
  ]

  def byte_size(), do: 82

  def init(opts) do
    schema = [
      payer: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account that will pay for the mint creation"
      ],
      balance: [
        type: :non_neg_integer,
        required: true,
        doc: "The lamport balance the mint account should have"
      ],
      program_id: [
        type: {:custom, Solana.Key, :check, []},
        doc: "Public key of the program which will own the created mint account",
        default: SystemProgram.id()
      ],
      decimals: [
        type: {:in, 0..255},
        required: true,
        doc: "decimals for the new mint"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "authority for the new mint"
      ],
      freeze_authority: [
        type: {:custom, Solana.Key, :check, []},
        doc: "freeze authority for the new mint"
      ],
      new: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "public key for the new mint"
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
            program_id: params.program_id
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
      ],
      data:
        Instruction.encode_data([
          0,
          params.decimals,
          params.authority
          | add_freeze_authority(params)
        ])
    }
  end

  defp add_freeze_authority(%{freeze_authority: freeze_authority}) do
    [1, freeze_authority]
  end

  defp add_freeze_authority(_params), do: [0, <<0::32*8>>]
end
