defmodule Solana.SPL.Token do
  @moduledoc """
  Functions for interacting with Solana's [Token
  Program](https://spl.solana.com/token).
  """
  alias Solana.{Instruction, Account, SystemProgram}
  import Solana.Helpers

  @typedoc "Token account metadata."
  @type t :: %__MODULE__{
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
    :mint,
    :owner,
    :amount,
    :delegate,
    :rent_exempt_reserve,
    :close_authority,
    delegated_amount: 0,
    initialized?: false,
    frozen?: false,
    native?: false
  ]

  @doc """
  The Token Program's ID.
  """
  @spec id() :: binary
  def id(), do: Solana.pubkey!("TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA")

  @doc """
  The size of a serialized token account.
  """
  @spec byte_size() :: pos_integer
  def byte_size(), do: 165

  @doc """
  Translates the result of a `Solana.RPC.Request.get_account_info/2` into a
  `t:Solana.SPL.Token.t/0`.
  """
  @spec from_account_info(info :: map) :: t | :error
  def from_account_info(info)

  def from_account_info(%{"data" => %{"parsed" => %{"info" => info}}}) do
    case from_token_account_info(info) do
      :error -> :error
      token -> Enum.reduce(info, token, &add_info/2)
    end
  end

  def from_account_info(_), do: :error

  defp from_token_account_info(%{
         "isNative" => native?,
         "mint" => mint,
         "owner" => owner,
         "tokenAmount" => %{"amount" => amount}
       }) do
    %__MODULE__{
      native?: native?,
      mint: B58.decode58!(mint),
      owner: B58.decode58!(owner),
      amount: String.to_integer(amount)
    }
  end

  defp from_token_account_info(_), do: :error

  defp add_info({"state", "initialized"}, token) do
    %{token | initialized?: true}
  end

  defp add_info({"state", "frozen"}, token) do
    %{token | initialized?: true, frozen?: true}
  end

  defp add_info({"delegate", delegate}, token) do
    %{token | delegate: B58.decode58!(delegate)}
  end

  defp add_info({"delegatedAmount", %{"amount" => amount}}, token) do
    %{token | delegated_amount: String.to_integer(amount)}
  end

  defp add_info(_, token), do: token

  @init_schema [
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
  @doc """
  Creates the instructions which initialize a new account to hold tokens.

  If this account is associated with the native mint then the token balance of
  the initialized account will be equal to the amount of SOL in the account. If
  this account is associated with another mint, that mint must be initialized
  before this command can succeed.

  All instructions must be executed as part of the same transaction. Otherwise
  another party can acquire ownership of the uninitialized account.

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
            program_id: id()
          ),
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

  @transfer_schema [
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
      doc: "The owner of `from`"
    ],
    multi_signers: [
      type: {:list, {:custom, Solana.Key, :check, []}},
      doc: "signing accounts if the `owner` is a `Solana.SPL.Token.MultiSig` account"
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
      doc: "The number of decimals in the `amount`. Only used if `checked?` is true."
    ],
    mint: [
      type: {:custom, Solana.Key, :check, []},
      doc: "The mint account for `from` and `to`. Only used if `checked?` is true."
    ]
  ]

  @doc """
  Creates an instruction to transfer tokens from one account to another either
  directly or via a delegate.

  If this account is associated with the native mint then equal amounts of SOL
  and Tokens will be transferred to the destination account.

  If you want to check the token's `mint` and `decimals`, set the `checked?`
  option to `true` and provide the `mint` and `decimals` options.

  ## Options

  #{NimbleOptions.docs(@transfer_schema)}
  """
  def transfer(opts) do
    case validate(opts, @transfer_schema) do
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

  @approve_schema [
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
      doc: "The account which owns `source`"
    ],
    multi_signers: [
      type: {:list, {:custom, Solana.Key, :check, []}},
      doc: "signing accounts if the `owner` is a `Solana.SPL.Token.MultiSig` account"
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
      doc: "The number of decimals in the `amount`. Only used if `checked?` is true."
    ],
    mint: [
      type: {:custom, Solana.Key, :check, []},
      doc: "The mint account for `from` and `to`. Only used if `checked?` is true."
    ]
  ]

  @doc """
  Creates an instruction to approves a delegate.

  A delegate is given the authority over tokens on behalf of the source
  account's owner.

  If you want to check the token's `mint` and `decimals`, set the `checked?`
  option to `true` and provide the `mint` and `decimals` options.

  ## Options

  #{NimbleOptions.docs(@approve_schema)}
  """
  def approve(opts) do
    case validate(opts, @approve_schema) do
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

  @revoke_schema [
    source: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The account to send tokens from"
    ],
    owner: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The account which owns `source`"
    ],
    multi_signers: [
      type: {:list, {:custom, Solana.Key, :check, []}},
      doc: "signing accounts if the `owner` is a `Solana.SPL.Token.MultiSig` account"
    ]
  ]
  @doc """
  Creates an instruction to revoke a previously approved delegate's authority to
  make transfers.

  ## Options

  #{NimbleOptions.docs(@revoke_schema)}
  """
  def revoke(opts) do
    case validate(opts, @revoke_schema) do
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

  @set_authority_schema [
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
      doc: "signing accounts if the `authority` is a `Solana.SPL.Token.MultiSig` account"
    ]
  ]

  @doc """
  Creates an instruction to set a new authority for a mint or account.

  ## Options

  #{NimbleOptions.docs(@set_authority_schema)}
  """
  def set_authority(opts) do
    case validate(opts, @set_authority_schema) do
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

  @mint_to_schema [
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
      doc: "signing accounts if the `authority` is a `Solana.SPL.Token.MultiSig` account"
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
      doc: "The number of decimals in the `amount`. Only used if `checked?` is true."
    ]
  ]
  @doc """
  Creates an instruction to mints new tokens to an account.

  The native mint does not support minting.

  If you want to check the token's `mint` and `decimals`, set the `checked?`
  option to `true` and provide the `decimals` option.

  ## Options

  #{NimbleOptions.docs(@mint_to_schema)}
  """
  def mint_to(opts) do
    case validate(opts, @mint_to_schema) do
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

  defp add_mint_to_data(ix, %{checked?: false, amount: amount}) do
    %{ix | data: Instruction.encode_data([7, {amount, 64}])}
  end

  defp add_mint_to_data(_, _), do: {:error, :invalid_checked_params}

  @burn_schema [
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
      doc: "the owner of `token`"
    ],
    amount: [
      type: :pos_integer,
      required: true,
      doc: "amount of tokens to burn"
    ],
    multi_signers: [
      type: {:list, {:custom, Solana.Key, :check, []}},
      doc: "signing accounts if the `owner` is a `Solana.SPL.Token.MultiSig` account"
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
      doc: "The number of decimals in the `amount`. Only used if `checked?` is true."
    ]
  ]

  @doc """
  Creates an instruction to burn tokens by removing them from an account.

  `burn/1` does not support accounts associated with the native mint, use
  `close_account/1` instead.

  If you want to check the token's `mint` and `decimals`, set the `checked?`
  option to `true` and provide the `decimals` option.

  ## Options

  #{NimbleOptions.docs(@burn_schema)}
  """
  def burn(opts) do
    case validate(opts, @burn_schema) do
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

  defp add_burn_data(ix, %{checked?: false, amount: amount}) do
    %{ix | data: Instruction.encode_data([8, {amount, 64}])}
  end

  defp add_burn_data(_, _), do: {:error, :invalid_checked_params}

  @close_account_schema [
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
      doc: "signing accounts if the `authority` is a `Solana.SPL.Token.MultiSig` account"
    ]
  ]
  @doc """
  Creates an instruction to close an account by transferring all its SOL to the
  `destination` account.

  A non-native account may only be closed if its token amount is zero.

  ## Options

  #{NimbleOptions.docs(@close_account_schema)}
  """
  def close_account(opts) do
    case validate(opts, @close_account_schema) do
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

  @freeze_schema [
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
      doc: "signing accounts if the `authority` is a `Solana.SPL.Token.MultiSig` account"
    ]
  ]
  @doc """
  Creates an instruction to freeze an initialized account using the mint's
  `freeze_authority` (if set).

  ## Options

  #{NimbleOptions.docs(@freeze_schema)}
  """
  def freeze(opts) do
    case validate(opts, @freeze_schema) do
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

  @thaw_schema [
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
      doc: "signing accounts if the `authority` is a `Solana.SPL.Token.MultiSig` account"
    ]
  ]
  @doc """
  Creates an instruction to thaw a frozen account using the mint's
  `freeze_authority` (if set).

  ## Options

  #{NimbleOptions.docs(@thaw_schema)}
  """
  def thaw(opts) do
    case validate(opts, @thaw_schema) do
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

  defp signer_accounts(params = %{owner: owner}) do
    params
    |> Map.delete(:owner)
    |> Map.put(:authority, owner)
    |> signer_accounts()
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
