defmodule Solana.SystemProgram.Nonce do
  @moduledoc """
  Functions for interacting with the [System
  Program](https://docs.solana.com/developing/runtime-facilities/programs#system-program)'s
  nonce accounts, required for [durable transaction
  nonces](https://docs.solana.com/offline-signing/durable-nonce).

  These accounts can be useful for offline transactions, as well as transactions
  that require more time to generate a transaction signature than the normal
  `recent_blockhash` transaction mechanism gives them (~2 minutes).
  """
  alias Solana.{Instruction, Account, SystemProgram}
  import Solana.Helpers

  @doc """
  The size of a serialized nonce account.
  """
  def byte_size(), do: 80

  @doc """
  Translates the result of a `Solana.RPC.Request.get_account_info/2` into a
  nonce account's information.
  """
  @spec from_account_info(info :: map) :: map | :error
  def from_account_info(%{"data" => %{"parsed" => %{"info" => info}}}) do
    from_nonce_account_info(info)
  end

  def from_account_info(_), do: :error

  defp from_nonce_account_info(%{
         "authority" => authority,
         "blockhash" => blockhash,
         "feeCalculator" => calculator
       }) do
    %{
      authority: Solana.pubkey!(authority),
      blockhash: B58.decode58!(blockhash),
      calculator: calculator
    }
  end

  defp from_nonce_account_info(_), do: :error

  @init_schema [
    nonce: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce account"
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce authority"
    ]
  ]
  @doc """
  Generates the instructions for initializing a nonce account.

  ## Options

  #{NimbleOptions.docs(@init_schema)}
  """
  def init(opts) do
    case validate(opts, @init_schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: Solana.recent_blockhashes()},
            %Account{key: Solana.rent()}
          ],
          data: Instruction.encode_data([{6, 32}, params.authority])
        }

      error ->
        error
    end
  end

  @authorize_schema [
    nonce: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce account"
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce authority"
    ],
    new_authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key to set as the new nonce authority"
    ]
  ]
  @doc """
  Generates the instructions for re-assigning the authority of a nonce account.

  ## Options

  #{NimbleOptions.docs(@authorize_schema)}
  """
  def authorize(opts) do
    case validate(opts, @authorize_schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: params.authority, signer?: true}
          ],
          data: Instruction.encode_data([{7, 32}, params.new_authority])
        }

      error ->
        error
    end
  end

  @advance_schema [
    nonce: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce account"
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce authority"
    ]
  ]
  @doc """
  Generates the instructions for advancing a nonce account's stored nonce value.

  ## Options

  #{NimbleOptions.docs(@advance_schema)}
  """
  def advance(opts) do
    case validate(opts, @advance_schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: Solana.recent_blockhashes()},
            %Account{key: params.authority, signer?: true}
          ],
          data: Instruction.encode_data([{4, 32}])
        }

      error ->
        error
    end
  end

  @withdraw_schema [
    nonce: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce account"
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the nonce authority"
    ],
    to: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the account which will get the withdrawn lamports"
    ],
    lamports: [
      type: :pos_integer,
      required: true,
      doc: "Amount of lamports to transfer to the created account"
    ]
  ]
  @doc """
  Generates the instructions for withdrawing funds form a nonce account.

  ## Options

  #{NimbleOptions.docs(@withdraw_schema)}
  """
  def withdraw(opts) do
    case validate(opts, @withdraw_schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: params.to, writable?: true},
            %Account{key: Solana.recent_blockhashes()},
            %Account{key: Solana.rent()},
            %Account{key: params.authority, signer?: true}
          ],
          data: Instruction.encode_data([{5, 32}, {params.lamports, 64}])
        }

      error ->
        error
    end
  end
end
