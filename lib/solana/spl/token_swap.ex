defmodule Solana.SPL.TokenSwap do
  @moduledoc """
  Functions for interacting with Solana's [Token Swap
  Program](https://spl.solana.com/token-swap).
  """
  alias Solana.{Instruction, Account, SystemProgram}
  import Solana.Helpers

  @curves [:constant_product, :constant_price, :stable, :offset]

  @doc """
  The Token Swap Program's ID.
  """
  @spec id() :: binary
  def id(), do: Solana.pubkey!("SwaPpA9LAaLfeLi3a68M4DjnLqgtticKg6CnyNwgAC8")

  @doc """
  The size of a serialized token swap account.
  """
  @spec byte_size() :: pos_integer
  def byte_size(), do: 324

  @doc false
  def validate_fee(f = {n, d})
  when is_integer(n) and n > 0 and is_integer(d) and d > 0 do
    {:ok, f}
  end

  def validate_fee({_n, 0}), do: {:error, "fee denominator cannot be 0"}

  def validate_fee(f), do: {:error, "expected a fee, got: #{inspect f}"}

  @doc false
  def validate_curve({type, params}) when type in @curves do
    {:ok, {type, params}}
  end

  def validate_curve(c) do
    {:error, "expected a curve in #{inspect @curves}, got: #{inspect c}"}
  end

  @init_schema [
    payer: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The account that will pay for the token swap account creation."
    ],
    balance: [
      type: :non_neg_integer,
      required: true,
      doc: "The lamport balance the token swap account should have."
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token swap account's swap authority"
    ],
    new: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The public key of the newly-created token swap account."
    ],
    token_a: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `A` token account in token swaps. Must be owned by `authority."
    ],
    token_b: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `B` token account in token swaps. Must be owned by `authority."
    ],
    pool: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token account which holds outside liquidity and enables A/B trades."
    ],
    pool_mint: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The mint of the `pool`."
    ],
    fee_account: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token account which receives all trading and withdrawal fees."
    ],
    trade_fee: [
      type: {:custom, __MODULE__, :validate_fee, []},
      default: {0, 1},
      doc: """
      The `new` swap account's trading fee. Trade fees are extra token amounts
      that are held inside the token accounts during a trade, making the value
      of liquidity tokens rise.
      """
    ],
    owner_trade_fee: [
      type: {:custom, __MODULE__, :validate_fee, []},
      default: {0, 1},
      doc: """
      The `new` swap account's owner trading fee. Owner trading fees are extra
      token amounts that are held inside the token accounts during a trade, with
      the equivalent in pool tokens minted to the owner of the program.
      """
    ],
    owner_withdraw_fee: [
      type: {:custom, __MODULE__, :validate_fee, []},
      default: {0, 1},
      doc: """
      The `new` swap account's owner withdraw fee. Owner withdraw fees are extra
      liquidity pool token amounts that are sent to the owner on every
      withdrawal.
      """
    ],
    host_fee: [
      type: {:custom, __MODULE__, :validate_fee, []},
      default: {0, 1},
      doc: """
      The `new` swap account's host fee. Host fees are a proportion of the
      owner trading fees, sent to an extra account provided during the trade.
      """
    ],
    curve: [
      type: {:custom, __MODULE__, :validate_curve, []},
      required: true,
      doc: """
      The automated market maker (AMM) curve to use for the `new` token swap account.
      Should take the form `{type, params}. See [the
      docs](https://spl.solana.com/token-swap#curves) on which curves are available.
      """
    ],
  ]
  @doc """
  Creates the instructions which initialize a new token swap account.

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
        %Account{key: params.authority},
        %Account{key: params.token_a},
        %Account{key: params.token_b},
        %Account{key: params.pool_mint, writable?: true},
        %Account{key: params.fee_account},
        %Account{key: params.pool, writable?: true},
        %Account{key: Solana.SPL.Token.id()},
      ],
      data: Instruction.encode_data(initialize_data(params))
    }
  end

  defp initialize_data(params = %{curve: {type, parameters}}) do
    [
      0,
      encode_fee(params.trade_fee),
      encode_fee(params.owner_trade_fee),
      encode_fee(params.owner_withdraw_fee),
      encode_fee(params.host_fee),
      Enum.find_index(@curves, & &1 == type),
      {parameters, 32*8}
    ]
    |> List.flatten()
  end

  defp encode_fee({n, d}), do: [{n, 64}, {d, 64}]

  @swap_schema [
    swap: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token swap to use."
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "the `swap` account's swap authority."
    ],
    user_source: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "User's source token account."
    ],
    pool_source: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Pool's source token account."
    ],
    user_destination: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "User's destination token account."
    ],
    pool_destination: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Pool's destination token account."
    ],
    pool_mint: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` pool mint."
    ],
    fee_account: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token account which receives all trading and withdrawal fees."
    ],
    host_fee_account: [
      type: {:custom, Solana.Key, :check, []},
      doc: "Host account to gather fees."
    ],
    user_authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Account delegated to transfer the user's tokens."
    ],
    amount: [
      type: :pos_integer,
      required: true,
      doc: "Amount to transfer from the source account."
    ],
    minimum_return: [
      type: :pos_integer,
      required: true,
      doc: "Minimum number of tokens the user will receive."
    ]
  ]
  @doc """
  Swap token `A` for token `B`.

  ## Options

  #{NimbleOptions.docs(@swap_schema)}
  """
  def swap(opts) do
    case validate(opts, @swap_schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: List.flatten([
            %Account{key: params.swap},
            %Account{key: params.authority},
            %Account{key: params.user_authority, signer?: true},
            %Account{key: params.user_source, writable?: true},
            %Account{key: params.pool_source, writable?: true},
            %Account{key: params.pool_destination, writable?: true},
            %Account{key: params.user_destination, writable?: true},
            %Account{key: params.pool_mint, writable?: true},
            %Account{key: params.fee_account, writable?: true},
            %Account{key: Solana.SPL.Token.id()},
            host_fee_account(params)
          ]),
          data: Instruction.encode_data([1, {params.amount, 64}, {params.mimimum_return, 64}])
        }
      error ->
        error
    end
  end

  defp host_fee_account(%{host_fee_account: key}) do
    [%Account{key: key, writable?: true}]
  end

  defp host_fee_account(_), do: []

  @deposit_all_schema [
    swap: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token swap to use."
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "the `swap` account's swap authority."
    ],
    user_a: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for token `A`."
    ],
    user_b: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for token `B`."
    ],
    swap_a: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `A`."
    ],
    swap_b: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `B`."
    ],
    user_pool: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for the pool token. Pool tokens will be deposited here."
    ],
    swap_pool: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for the pool token. Pool tokens will be withdrawn from here."
    ],
    user_authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Account delegated to transfer the user's tokens."
    ],
    amount_a: [
      type: :pos_integer,
      required: true,
      doc: "Maximum amount of token `A` to deposit."
    ],
    amount_b: [
      type: :pos_integer,
      required: true,
      doc: "Maximum amount of token `B` to deposit."
    ],
    amount_pool: [
      type: :pos_integer,
      required: true,
      doc: "Amount of pool tokens to mint."
    ],
  ]
  @doc """
  Deposits both `A` and `B` tokens into the pool.

  ## Options

  #{NimbleOptions.docs(@deposit_all_schema)}
  """
  def deposit_all(opts) do
    case validate(opts, @deposit_all_schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: List.flatten([
            %Account{key: params.swap},
            %Account{key: params.authority},
            %Account{key: params.user_authority, signer?: true},
            %Account{key: params.user_a, writable?: true},
            %Account{key: params.user_b, writable?: true},
            %Account{key: params.swap_a, writable?: true},
            %Account{key: params.swap_b, writable?: true},
            %Account{key: params.swap_pool, writable?: true},
            %Account{key: params.user_pool, writable?: true},
            %Account{key: Solana.SPL.Token.id()},
          ]),
          data: Instruction.encode_data([2, {params.amount_pool, 64}, {params.amount_a, 64}, {params.amount_b, 64}])
        }
      error ->
        error
    end
  end

  @withdraw_all_schema [
    swap: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token swap to use."
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "the `swap` account's swap authority."
    ],
    user_a: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for token `A`."
    ],
    user_b: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for token `B`."
    ],
    swap_a: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `A`."
    ],
    swap_b: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `B`."
    ],
    user_pool: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for the pool token. Pool tokens with be withdrawn from here."
    ],
    pool_mint: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The pool token's mint."
    ],
    user_authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Account delegated to transfer the user's tokens."
    ],
    fee_account: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token account which receives all trading and withdrawal fees."
    ],
    amount_a: [
      type: :pos_integer,
      required: true,
      doc: "Minimum amount of token `A` to withdraw."
    ],
    amount_b: [
      type: :pos_integer,
      required: true,
      doc: "Minimum amount of token `B` to withdraw."
    ],
    amount_pool: [
      type: :pos_integer,
      required: true,
      doc: "Amount of pool tokens to burn."
    ],
  ]
  @doc """
  Withdraws both `A` and `B` tokens from the pool.

  ## Options

  #{NimbleOptions.docs(@withdraw_all_schema)}
  """
  def withdraw_all(opts) do
    case validate(opts, @withdraw_all_schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: List.flatten([
            %Account{key: params.swap},
            %Account{key: params.authority},
            %Account{key: params.user_authority, signer?: true},
            %Account{key: params.pool_mint, writable?: true},
            %Account{key: params.user_pool, writable?: true},
            %Account{key: params.swap_a, writable?: true},
            %Account{key: params.swap_b, writable?: true},
            %Account{key: params.user_a, writable?: true},
            %Account{key: params.user_b, writable?: true},
            %Account{key: params.fee_account, writable?: true},
            %Account{key: Solana.SPL.Token.id()},
          ]),
          data: Instruction.encode_data([3, {params.amount_pool, 64}, {params.amount_a, 64}, {params.amount_b, 64}])
        }
      error ->
        error
    end
  end

  @deposit_schema [
    swap: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token swap to use."
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "the `swap` account's swap authority."
    ],
    user_token: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for token `A` or `B`."
    ],
    swap_a: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `A`."
    ],
    swap_b: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `B`."
    ],
    user_pool: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for the pool token. Pool tokens will be deposited here."
    ],
    swap_pool: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for the pool token. Pool tokens will be withdrawn from here."
    ],
    user_authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Account delegated to transfer the user's tokens."
    ],
    amount: [
      type: :pos_integer,
      required: true,
      doc: "Amount of token `A` or `B` to deposit."
    ],
    amount_pool: [
      type: :pos_integer,
      required: true,
      doc: "Minimum amount of pool tokens to mint."
    ],
  ]
  @doc """
  Deposits `A` or `B` tokens into the pool.

  ## Options

  #{NimbleOptions.docs(@deposit_schema)}
  """
  def deposit(opts) do
    case validate(opts, @deposit_schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: List.flatten([
            %Account{key: params.swap},
            %Account{key: params.authority},
            %Account{key: params.user_authority, signer?: true},
            %Account{key: params.user_token, writable?: true},
            %Account{key: params.swap_a, writable?: true},
            %Account{key: params.swap_b, writable?: true},
            %Account{key: params.swap_pool, writable?: true},
            %Account{key: params.user_pool, writable?: true},
            %Account{key: Solana.SPL.Token.id()},
          ]),
          data: Instruction.encode_data([4, {params.amount, 64}, {params.amount_pool, 64}])
        }
      error ->
        error
    end
  end

  @withdraw_schema [
    swap: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token swap to use."
    ],
    authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "the `swap` account's swap authority."
    ],
    user_token: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for token `A` or `B`."
    ],
    swap_a: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `A`."
    ],
    swap_b: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The `swap` account for token `B`."
    ],
    user_pool: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The user's account for the pool token. Pool tokens with be withdrawn from here."
    ],
    pool_mint: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The pool token's mint."
    ],
    user_authority: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Account delegated to transfer the user's tokens."
    ],
    fee_account: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The token account which receives all trading and withdrawal fees."
    ],
    amount: [
      type: :pos_integer,
      required: true,
      doc: "Amount of token `A` or `B` to withdraw."
    ],
    amount_pool: [
      type: :pos_integer,
      required: true,
      doc: "Maximum amount of pool tokens to burn."
    ],
  ]
  @doc """
  Withdraws `A` or `B` tokens from the pool.

  ## Options

  #{NimbleOptions.docs(@withdraw_schema)}
  """
  def withdraw(opts) do
    case validate(opts, @withdraw_schema) do
      {:ok, params} ->
        %Instruction{
          program: id(),
          accounts: List.flatten([
            %Account{key: params.swap},
            %Account{key: params.authority},
            %Account{key: params.user_authority, signer?: true},
            %Account{key: params.pool_mint, writable?: true},
            %Account{key: params.user_pool, writable?: true},
            %Account{key: params.pool_a, writable?: true},
            %Account{key: params.pool_b, writable?: true},
            %Account{key: params.user_token, writable?: true},
            %Account{key: params.fee_account, writable?: true},
            %Account{key: Solana.SPL.Token.id()},
          ]),
          data: Instruction.encode_data([5, {params.amount, 64}, {params.amount_pool, 64}])
        }
      error ->
        error
    end
  end
end
