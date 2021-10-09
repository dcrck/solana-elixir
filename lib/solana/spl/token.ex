defmodule Solana.SPL.Token do
  alias Solana.{Instruction, Account, SystemProgram}
  import Solana.Helpers

  @type t :: %__MODULE__{
          address: Solana.key(),
          mint: Solana.key(),
          owner: Solana.key(),
          amount: non_neg_integer,
          delegate: Solana.key() | nil,
          delegated_amount: non_neg_integer,
          initialized?: boolean,
          frozen?: boolean,
          native?: boolean,
          rent_exempt_reserve: non_neg_integer | nil,
          close_authority: Solana.key() | nil
        }

  @authority_types [:mint, :freeze, :owner, :close]

  defstruct [
    :address,
    :mint,
    :owner,
    :amount,
    :delegate,
    :delegated_amount,
    :rent_exempt_reserve,
    :close_authority,
    initialized?: false,
    frozen?: false,
    native?: false
  ]

  def id(), do: Solana.pubkey!("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")

  def byte_size(), do: 165

  @doc """
  Creates the instructions which initialize a new account to hold tokens.
  If this account is associated with the native mint then the token balance of
  the initialized account will be equal to the amount of SOL in the account. If
  this account is associated with another mint, that mint must be initialized
  before this command can succeed.

  All instructions must be executed as part of the same transaction. Otherwise
  another party can acquire ownership of the uninitialized account.
  """
  def init(opts) do
    schema = [
      payer: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account that will pay for the token account creation"
      ],
      balance: [
        type: :non_neg_integer,
        required: true,
        doc: "The lamport balance the token account should have"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The mint of the newly-created token account"
      ],
      owner: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The owner of the newly-created token account"
      ],
      new: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The public key of the newly-created token account"
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
            program_id: id()
          }),
          initialize_ix(params)
        ]

      error ->
        error
    end
  end

  defp initialize_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.new, writable?: true},
        %Account{key: params.mint},
        %Account{key: params.owner},
        %Account{key: Solana.rent()}
      ],
      data: Instruction.encode_data([1])
    }
  end

  @doc """
  Creates an instruction to transfer tokens from one account to another either
  directly or via a delegate. If this account is associated with the native mint
  then equal amounts of SOL and Tokens will be transferred to the destination
  account.
  """
  def transfer(opts) do
    schema = [
      from: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account to send tokens from"
      ],
      to: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account to receive tokens"
      ],
      owner: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        rename_to: :authority,
        doc: "The owner of `from`"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `owner` is a `multi_sig` account"
      ],
      amount: [
        type: :pos_integer,
        required: true,
        doc: "The number of tokens to send"
      ],
      checked?: [
        type: :boolean,
        default: false,
        doc: """
        whether or not to check the token mint and decimals; may be useful
        when creating transactions offline or within a hardware wallet.
        """
      ],
      decimals: [
        type: {:in, 0..255},
        doc: "The number of decimals in the `amount`"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        doc: "The mint account for `from` and `to`"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params = %{checked?: true, mint: mint, decimals: decimals}} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.from, writable?: true},
            %Account{key: mint},
            %Account{key: params.to, writable?: true}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([12, {params.amount, 64}, decimals])
        }

      {:ok, params = %{checked?: false}} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.from, writable?: true},
            %Account{key: params.to, writable?: true}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([3, {params.amount, 64}])
        }

      {:ok, _} ->
        {:error, :invalid_checked_params}

      error ->
        error
    end
  end

  @doc """
  Creates an instruction to approves a delegate. A delegate is given the
  authority over tokens on behalf of the source account's owner.
  """
  def approve(opts) do
    schema = [
      source: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account to send tokens from"
      ],
      delegate: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account authorized to perform a transfer of tokens from `source`"
      ],
      owner: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        rename_to: :authority,
        doc: "The account which owns `source`"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `owner` is a `multi_sig` account"
      ],
      amount: [
        type: :pos_integer,
        required: true,
        doc: "The maximum number of tokens that `delegate` can send on behalf of `source`"
      ],
      checked?: [
        type: :boolean,
        default: false,
        doc: """
        whether or not to check the token mint and decimals; may be useful
        when creating transactions offline or within a hardware wallet.
        """
      ],
      decimals: [
        type: {:in, 0..255},
        doc: "The number of decimals in the `amount`"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        doc: "The mint account for `from` and `to`"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params = %{checked?: true, mint: mint, decimals: decimals}} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.source, writable?: true},
            %Account{key: mint},
            %Account{key: params.delegate}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([13, {params.amount, 64}, decimals])
        }

      {:ok, params = %{checked?: false}} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.source, writable?: true},
            %Account{key: params.delegate}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([4, {params.amount, 64}])
        }

      {:ok, _} ->
        {:error, :invalid_checked_params}

      error ->
        error
    end
  end

  @doc """
  Creates an instruction to revoke a previously approved delegate's authority to
  make transfers.
  """
  def revoke(opts) do
    schema = [
      source: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account to send tokens from"
      ],
      owner: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        rename_to: :authority,
        doc: "The account which owns `source`"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `owner` is a `multi_sig` account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.source, writable?: true}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([5])
        }

      error ->
        error
    end
  end

  @doc """
  Creates an instruction to set a new authority for a mint or account.
  """
  def set_authority(opts) do
    schema = [
      account: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account which will change authority, either a mint or token account"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "the current authority for `mint_or_token`"
      ],
      new_authority: [
        type: {:custom, Solana.Key, :check, []},
        doc: "the new authority for `mint_or_token`"
      ],
      type: [
        type: {:in, @authority_types},
        required: true,
        doc: "type of authority to set"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `authority` is a `multi_sig` account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.account, writable?: true}
            | signer_accounts(params)
          ],
          data:
            Instruction.encode_data([
              6,
              Enum.find_index(@authority_types, &(&1 == params.type))
              | add_new_authority(params)
            ])
        }

      error ->
        error
    end
  end

  defp add_new_authority(%{new_authority: new_authority}) do
    [1, new_authority]
  end

  defp add_new_authority(_params), do: [0, <<0::32*8>>]

  @doc """
  Creates an instruction to mints new tokens to an account. The native mint does
  not support minting.
  """
  def mint_to(opts) do
    schema = [
      token: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The token account which will receive the minted tokens"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The mint account which will mint the tokens"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "the current mint authority"
      ],
      amount: [
        type: :pos_integer,
        required: true,
        doc: "amount of tokens to mint"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `authority` is a `multi_sig` account"
      ],
      checked?: [
        type: :boolean,
        default: false,
        doc: """
        whether or not to check the token mint and decimals; may be useful
        when creating transactions offline or within a hardware wallet.
        """
      ],
      decimals: [
        type: {:in, 0..255},
        doc: "The number of decimals in the `amount`"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.mint, writable?: true},
            %Account{key: params.token, writable?: true}
            | signer_accounts(params)
          ]
        }
        |> add_mint_to_data(params)

      error ->
        error
    end
  end

  defp add_mint_to_data(ix, %{checked?: true, decimals: decimals, amount: amount}) do
    %{ix | data: Instruction.encode_data([14, {amount, 64}, decimals])}
  end

  defp add_mint_to_data(ix, %{checked: false, amount: amount}) do
    %{ix | data: Instruction.encode_data([7, {amount, 64}])}
  end

  defp add_mint_to_data(_, _), do: {:error, :invalid_checked_params}

  @doc """
  Creates an instruction to burn tokens by removing them from an account.
  `burn/1` does not support accounts associated with the native mint, use
  `close_account/1` instead.
  """
  def burn(opts) do
    schema = [
      token: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The token account which will have its tokens burned"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The mint account which will burn the tokens"
      ],
      owner: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        rename_to: :authority,
        doc: "the owner of `token`"
      ],
      amount: [
        type: :pos_integer,
        required: true,
        doc: "amount of tokens to burn"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `owner` is a `multi_sig` account"
      ],
      checked?: [
        type: :boolean,
        default: false,
        doc: """
        whether or not to check the token mint and decimals; may be useful
        when creating transactions offline or within a hardware wallet.
        """
      ],
      decimals: [
        type: {:in, 0..255},
        doc: "The number of decimals in the `amount`"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.token, writable?: true},
            %Account{key: params.mint, writable?: true}
            | signer_accounts(params)
          ]
        }
        |> add_burn_data(params)

      error ->
        error
    end
  end

  defp add_burn_data(ix, %{checked?: true, decimals: decimals, amount: amount}) do
    %{ix | data: Instruction.encode_data([15, {amount, 64}, decimals])}
  end

  defp add_burn_data(ix, %{checked: false, amount: amount}) do
    %{ix | data: Instruction.encode_data([8, {amount, 64}])}
  end

  defp add_burn_data(_, _), do: {:error, :invalid_checked_params}

  @doc """
  Creates an instruction to close an account by transferring all its SOL to the
  `destination` account. Non-native accounts may only be closed if its token
  amount is zero.
  """
  def close_account(opts) do
    schema = [
      to_close: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account to close"
      ],
      destination: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account which will receive the remaining balance of `to_close`"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "the `account close` authority for `to_close`"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `authority` is a `multi_sig` account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.to_close, writable?: true},
            %Account{key: params.destination, writable?: true}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([9])
        }

      error ->
        error
    end
  end

  @doc """
  Creates an instruction to freeze an initialized account using the mint's
  `freeze_authority` (if set).
  """
  def freeze(opts) do
    schema = [
      to_freeze: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account to freeze"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The mint account for `to_freeze`"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "the `freeze` authority for `mint`"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `authority` is a `multi_sig` account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.to_freeze, writable?: true},
            %Account{key: params.mint, writable?: true}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([10])
        }

      error ->
        error
    end
  end

  @doc """
  Creates an instruction to thaw a frozen account using the mint's
  `freeze_authority` (if set).
  """
  def thaw(opts) do
    schema = [
      to_thaw: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The account to thaw"
      ],
      mint: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "The mint account for `to_thaw`"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "the `freeze` authority for `mint`"
      ],
      multi_signers: [
        type: {:list, {:custom, Solana.Key, :check, []}},
        doc: "signing accounts if the `authority` is a `multi_sig` account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: [
            %Account{key: params.to_thaw, writable?: true},
            %Account{key: params.mint, writable?: true}
            | signer_accounts(params)
          ],
          data: Instruction.encode_data([11])
        }

      error ->
        error
    end
  end

  defp signer_accounts(%{multi_signers: signers, authority: authority}) do
    [
      %Account{key: authority}
      | Enum.map(signers, &%Account{key: &1, signer?: true})
    ]
  end

  defp signer_accounts(%{authority: authority}) do
    [%Account{key: authority, signer?: true}]
  end
end
