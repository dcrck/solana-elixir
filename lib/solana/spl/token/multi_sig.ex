defmodule Solana.SPL.Token.MultiSig do
  @moduledoc """
  Functions for dealing with multi-signature accounts.

  Multi-signature accounts can used in place of any single owner/delegate
  accounts in any token instruction that require an owner/delegate to be
  present.
  """

  alias Solana.{Instruction, Account, SPL.Token, SystemProgram}
  import Solana.Helpers

  @typedoc "Multi-signature account metadata."
  @type t :: %__MODULE__{
          signers_required: byte,
          signers_total: byte,
          initialized?: boolean,
          signers: [Solana.key()]
        }

  defstruct signers_required: 1,
            signers_total: 1,
            initialized?: false,
            signers: []

  @doc "The size of a serialized multi-signature account."
  def byte_size(), do: 355

  @doc """
  Translates the result of a `Solana.RPC.Request.get_account_info/2` into a
  `t:Solana.SPL.Token.MultiSig.t/0`.
  """
  @spec from_account_info(info :: map) :: t | :error
  def from_account_info(info)

  def from_account_info(%{"data" => %{"parsed" => %{"info" => info}}}) do
    from_multisig_account_info(info)
  end

  def from_account_info(_), do: :error

  defp from_multisig_account_info(%{
         "isInitialized" => initialized?,
         "numRequiredSigners" => signers_required,
         "numValidSigners" => signers_total,
         "signers" => signers
       }) do
    %__MODULE__{
      signers_required: signers_required,
      signers_total: signers_total,
      initialized?: initialized?,
      signers: Enum.map(signers, &B58.decode58!/1)
    }
  end

  defp from_multisig_account_info(_), do: :error

  @init_schema [
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
      doc: "The full set of signers; should be a list of 11 members or fewer"
    ],
    signatures_required: [
      type: {:in, 1..11},
      required: true,
      doc: "number of signatures required; should be between 1 and 11 (inclusive)"
    ],
    new: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "public key for the new multisig account"
    ]
  ]

  @doc """
  Creates the instructions to initialize a multisignature account.

  **These instructions must be included in the same Transaction.**

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
        | Enum.map(params.signers, &%Account{key: &1})
      ],
      data: Instruction.encode_data([2, params.signatures_required])
    }
  end
end
