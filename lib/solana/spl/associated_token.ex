defmodule Solana.SPL.AssociatedToken do
  @moduledoc """
  Functions for interacting with the Associated Token Account program.

  An associated token account's address is derived from a user's main system
  account and the token mint, which means each user can only have one associated
  token account per token.

  To learn more about why this is important, check out the [Solana
  documentation](https://github.com/solana-labs/solana-program-library/blob/master/docs/src/associated-token-account.md)
  """
  alias Solana.{SPL.Token, Key, Instruction, Account, SystemProgram}
  import Solana.Helpers

  def id(), do: Solana.pubkey!("ATokenGPvbdGVxr1b2hvZbsiqW5xWH25efTNsLJA8knL")

  @doc """
  Find the token account address associated with a given owner and mint
  """
  @spec find_address(mint :: Solana.key(), owner :: Solana.key()) :: {:ok, Solana.key()} | :error
  def find_address(mint, owner) do
    with true <- Ed25519.on_curve?(owner),
         {:ok, key, _} <- Key.find_address([owner, Token.id(), mint], id()) do
      {:ok, key}
    else
      _ -> :error
    end
  end

  def create_account(opts) do
    schema = [
      payer: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account which will pay for the `new` account's creation"
      ],
      owner: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account which will own the `new` account"
      ],
      new: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the associated token account to create"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The mint of the `new` account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.payer, writable?: true, signer?: true},
            %Account{key: params.new, writable?: true},
            %Account{key: params.owner},
            %Account{key: params.mint},
            %Account{key: SystemProgram.id()},
            %Account{key: Token.id()},
            %Account{key: Solana.rent()}
          ],
          data: Instruction.encode_data([0])
        }

      error ->
        error
    end
  end
end
