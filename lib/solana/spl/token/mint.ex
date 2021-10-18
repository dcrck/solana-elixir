defmodule Solana.SPL.Token.Mint do
  alias Solana.{Instruction, Account, SPL.Token, SystemProgram}
  import Solana.Helpers

  @type t :: %__MODULE__{
          authority: Solana.key() | nil,
          supply: non_neg_integer,
          decimals: byte,
          initialized?: boolean,
          freeze_authority: Solana.key() | nil,
        }

  defstruct [
    :authority,
    :supply,
    :freeze_authority,
    decimals: 0,
    initialized?: false
  ]

  @doc """
  Translates the result of a `get_account_info` RPC API call into a `Mint`.
  """
  def from_account_info(%{"data" => %{"parsed" => %{"type" => "mint", "info" => info}}}) do
    mint = %__MODULE__{
      decimals: info["decimals"],
      authority: B58.decode58!(info["mintAuthority"]),
      initialized?: info["isInitialized"],
      supply: String.to_integer(info["supply"])
    }

    case info["freezeAuthority"] do
      nil -> mint
      authority -> %{mint | freeze_authority: B58.decode58!(authority)}
    end
  end

  def from_account_info(_), do: :error

  def byte_size(), do: 82

  @doc """
  Genereates the instructions to initialize a `Mint`.
  """
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
          SystemProgram.create_account(
            lamports: params.balance,
            space: byte_size(),
            from: params.payer,
            new: params.new,
            program_id: Token.id()
          ),
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
