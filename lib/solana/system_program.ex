defmodule Solana.SystemProgram do
  @moduledoc """
  Functions for interacting with Solana's [System
  Program](https://docs.solana.com/developing/runtime-facilities/programs#system-program)
  """

  alias Solana.{Instruction, Account}
  import Solana.Helpers

  @doc """
  The System Program's program ID.
  """
  def id(), do: Solana.pubkey!("11111111111111111111111111111111")

  @create_account_schema [
    lamports: [
      type: :pos_integer,
      required: true,
      doc: "Amount of lamports to transfer to the created account"
    ],
    space: [
      type: :non_neg_integer,
      required: true,
      doc: "Amount of space in bytes to allocate to the created account"
    ],
    from: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "The account that will transfer lamports to the created account"
    ],
    new: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the created account"
    ],
    program_id: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key of the program which will own the created account"
    ],
    base: [
      type: {:custom, Solana.Key, :check, []},
      doc: "Base public key to use to derive the created account's address"
    ],
    seed: [
      type: :string,
      doc: "Seed to use to derive the created account's address"
    ]
  ]
  @doc """
  Generates instructions to create a new account. Accepts a `new` address
  generated via `Solana.Key.with_seed/3`, as long as the `base` key and `seed`
  used to generate that address are provided.

  ## Options

  #{NimbleOptions.docs(@create_account_schema)}
  """
  def create_account(opts) do
    case validate(opts, @create_account_schema) do
      {:ok, params} ->
        maybe_with_seed(
          params,
          &create_account_ix/1,
          &create_account_with_seed_ix/1,
          [:base, :seed]
        )

      error ->
        error
    end
  end

  @transfer_schema [
    lamports: [
      type: :pos_integer,
      required: true,
      doc: "Amount of lamports to transfer"
    ],
    from: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Account that will transfer lamports"
    ],
    to: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Account that will receive the transferred lamports"
    ],
    base: [
      type: {:custom, Solana.Key, :check, []},
      doc: "Base public key to use to derive the funding account address"
    ],
    seed: [
      type: :string,
      doc: "Seed to use to derive the funding account address"
    ],
    program_id: [
      type: {:custom, Solana.Key, :check, []},
      doc: "Program ID to use to derive the funding account address"
    ]
  ]
  @doc """
  Generates instructions to transfer lamports from one account to another.
  Accepts a `from` address generated via `Solana.Key.with_seed/3`, as long as the
  `base` key, `program_id`, and `seed` used to generate that address are
  provided.

  ## Options

  #{NimbleOptions.docs(@transfer_schema)}
  """
  def transfer(opts) do
    case validate(opts, @transfer_schema) do
      {:ok, params} ->
        maybe_with_seed(
          params,
          &transfer_ix/1,
          &transfer_with_seed_ix/1
        )

      error ->
        error
    end
  end

  @assign_schema [
    account: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key for the account which will receive a new owner"
    ],
    program_id: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Program ID to assign as the owner"
    ],
    base: [
      type: {:custom, Solana.Key, :check, []},
      doc: "Base public key to use to derive the assigned account address"
    ],
    seed: [
      type: :string,
      doc: "Seed to use to derive the assigned account address"
    ]
  ]
  @doc """
  Generates instructions to assign account ownership to a program.
  Accepts an `account` address generated via `Solana.Key.with_seed/3`, as long
  as the `base` key and `seed` used to generate that address are provided.

  ## Options

  #{NimbleOptions.docs(@assign_schema)}
  """
  def assign(opts) do
    case validate(opts, @assign_schema) do
      {:ok, params} ->
        maybe_with_seed(
          params,
          &assign_ix/1,
          &assign_with_seed_ix/1,
          [:base, :seed]
        )

      error ->
        error
    end
  end

  @allocate_schema [
    account: [
      type: {:custom, Solana.Key, :check, []},
      required: true,
      doc: "Public key for the account to allocate"
    ],
    space: [
      type: :non_neg_integer,
      required: true,
      doc: "Amount of space in bytes to allocate"
    ],
    program_id: [
      type: {:custom, Solana.Key, :check, []},
      doc: "Program ID to assign as the owner of the allocated account"
    ],
    base: [
      type: {:custom, Solana.Key, :check, []},
      doc: "Base public key to use to derive the allocated account address"
    ],
    seed: [
      type: :string,
      doc: "Seed to use to derive the allocated account address"
    ]
  ]
  @doc """
  Generates instructions to allocate space to an account.
  Accepts an `account` address generated via `Solana.Key.with_seed/3`, as long
  as the `base` key, `program_id`, and `seed` used to generate that address are
  provided.

  ## Options

  #{NimbleOptions.docs(@allocate_schema)}
  """
  def allocate(opts) do
    case validate(opts, @allocate_schema) do
      {:ok, params} ->
        maybe_with_seed(
          params,
          &allocate_ix/1,
          &allocate_with_seed_ix/1,
          [:base, :seed]
        )

      error ->
        error
    end
  end

  defp maybe_with_seed(opts, ix_fn, ix_seed_fn, keys \\ [:base, :seed, :program_id]) do
    key_check = Enum.map(keys, &Map.has_key?(opts, &1))

    cond do
      Enum.all?(key_check) -> ix_seed_fn.(opts)
      !Enum.any?(key_check) -> ix_fn.(opts)
      true -> {:error, :missing_seed_params}
    end
  end

  defp create_account_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.from, signer?: true, writable?: true},
        %Account{key: params.new, signer?: true, writable?: true}
      ],
      data:
        Instruction.encode_data([
          {0, 32},
          {params.lamports, 64},
          {params.space, 64},
          params.program_id
        ])
    }
  end

  defp create_account_with_seed_ix(params) do
    %Instruction{
      program: id(),
      accounts: create_account_with_seed_accounts(params),
      data:
        Instruction.encode_data([
          {3, 32},
          params.base,
          {params.seed, "str"},
          {params.lamports, 64},
          {params.space, 64},
          params.program_id
        ])
    }
  end

  defp create_account_with_seed_accounts(params = %{from: from, base: from}) do
    [
      %Account{key: from, signer?: true, writable?: true},
      %Account{key: params.new, writable?: true}
    ]
  end

  defp create_account_with_seed_accounts(params) do
    [
      %Account{key: params.from, signer?: true, writable?: true},
      %Account{key: params.new, writable?: true},
      %Account{key: params.base, signer?: true}
    ]
  end

  defp transfer_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.from, signer?: true, writable?: true},
        %Account{key: params.to, writable?: true}
      ],
      data: Instruction.encode_data([{2, 32}, {params.lamports, 64}])
    }
  end

  defp transfer_with_seed_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.from, writable?: true},
        %Account{key: params.base, signer?: true},
        %Account{key: params.to, writable?: true}
      ],
      data:
        Instruction.encode_data([
          {11, 32},
          {params.lamports, 64},
          {params.seed, "str"},
          params.program_id
        ])
    }
  end

  defp assign_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.account, signer?: true, writable?: true}
      ],
      data: Instruction.encode_data([{1, 32}, params.program_id])
    }
  end

  defp assign_with_seed_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.account, writable?: true},
        %Account{key: params.base, signer?: true}
      ],
      data:
        Instruction.encode_data([
          {10, 32},
          params.base,
          {params.seed, "str"},
          params.program_id
        ])
    }
  end

  defp allocate_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.account, signer?: true, writable?: true}
      ],
      data: Instruction.encode_data([{8, 32}, {params.space, 64}])
    }
  end

  defp allocate_with_seed_ix(params) do
    %Instruction{
      program: id(),
      accounts: [
        %Account{key: params.account, writable?: true},
        %Account{key: params.base, signer?: true}
      ],
      data:
        Instruction.encode_data([
          {9, 32},
          params.base,
          {params.seed, "str"},
          {params.space, 64},
          params.program_id
        ])
    }
  end
end
