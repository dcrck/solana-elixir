defmodule Solana.SPL.Token.Mint do
  @moduledoc """
  Functions for interacting with the mint accounts of Solana's [Token
  Program](https://spl.solana.com/token).
  """
  alias Solana.{Instruction, Account, SPL.Token, SystemProgram}
  import Solana.Helpers

  @typedoc "Token Program mint account metadata."
  @type t :: %__MODULE__{
          authority: Solana.key() | nil,
          supply: non_neg_integer,
          decimals: byte,
          initialized?: boolean,
          freeze_authority: Solana.key() | nil
        }

  defstruct [
    :authority,
    :supply,
    :freeze_authority,
    decimals: 0,
    initialized?: false
  ]

  @doc """
  The size of a serialized token mint account.
  """
  @spec byte_size() :: pos_integer
  def byte_size(), do: 82

  @doc """
  Translates the result of a `Solana.RPC.Request.get_account_info/2` into a
  `t:Solana.SPL.Token.Mint.t/0`.
  """
  @spec from_account_info(info :: map) :: t | :error
  def from_account_info(info)

  def from_account_info(%{"data" => %{"parsed" => %{"type" => "mint", "info" => info}}}) do
    case {from_mint_account_info(info), info["freezeAuthority"]} do
      {:error, _} -> :error
      {mint, nil} -> mint
      {mint, authority} -> %{mint | freeze_authority: B58.decode58!(authority)}
    end
  end

  def from_account_info(_), do: :error

  defp from_mint_account_info(%{
         "supply" => supply,
         "isInitialized" => initialized?,
         "mintAuthority" => authority,
         "decimals" => decimals
       }) do
    %__MODULE__{
      decimals: decimals,
      authority: B58.decode58!(authority),
      initialized?: initialized?,
      supply: String.to_integer(supply)
    }
  end

  defp from_mint_account_info(_), do: :error

  @init_schema [
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
  @doc """
  Genereates the instructions to initialize a mint account.

  ## Options

  #{NimbleOptions.docs(@init_schema)}
  """
  def init(opts) do
    case validate(opts, @init_schema) do
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
