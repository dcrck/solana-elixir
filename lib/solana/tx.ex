defmodule Solana.Transaction do
  require Logger
  alias Solana.{Account, CompactArray}

  @type t :: %__MODULE__{
          payer: Solana.key() | nil,
          blockhash: binary | nil,
          instructions: [Solana.Instruction.t()],
          signers: [Solana.keypair()]
        }

  @type encoding_err ::
          :no_payer
          | :no_blockhash
          | :no_program
          | :no_instructions
          | :mismatched_signers

  defstruct [
    :payer,
    :blockhash,
    instructions: [],
    signers: []
  ]

  @doc """
  Checks to see if a signature is valid
  """
  @spec check(binary) :: {:ok, binary} | {:error, :invalid_signature}
  def check(<<signature::binary-64>>), do: {:ok, signature}
  def check(_), do: {:error, :invalid_signature}

  @spec to_binary(tx :: t) :: {:ok, binary()} | {:error, encoding_err()}
  def to_binary(%__MODULE__{payer: nil}), do: {:error, :no_payer}
  def to_binary(%__MODULE__{blockhash: nil}), do: {:error, :no_blockhash}
  def to_binary(%__MODULE__{instructions: []}), do: {:error, :no_instructions}

  def to_binary(tx = %__MODULE__{instructions: ixs, signers: signers}) do
    ixs = List.flatten(ixs)
    with nil <- Enum.find_index(ixs, &is_nil(&1.program)),
         accounts = compile_accounts(ixs, tx.payer),
         true <- signers_match?(accounts, signers) do
      message = encode_message(accounts, tx.blockhash, ixs)

      signatures =
        signers
        |> reorder_signers(accounts)
        |> Enum.map(&sign(&1, message))
        |> CompactArray.to_iolist()

      {:ok, :erlang.list_to_binary([signatures, message])}
    else
      idx when is_integer(idx) ->
        Logger.error("Missing program id on instruction at index #{idx}")
        {:error, :no_program}

      false ->
        {:error, :mismatched_signers}
    end
  end

  defp compile_accounts(ixs, payer) do
    ixs
    |> Enum.map(fn ix -> [%Account{key: ix.program} | ix.accounts] end)
    |> List.flatten()
    |> Enum.reject(&(&1.key == payer))
    |> Enum.sort_by(&{&1.signer?, &1.writable?}, &>=/2)
    |> Enum.uniq_by(& &1.key)
    |> cons(%Account{writable?: true, signer?: true, key: payer})
  end

  defp cons(list, item), do: [item | list]

  defp signers_match?(accounts, signers) do
    expected = MapSet.new(Enum.map(signers, &elem(&1, 1)))

    accounts
    |> Enum.filter(& &1.signer?)
    |> Enum.map(& &1.key)
    |> MapSet.new()
    |> MapSet.equal?(expected)
  end

  defp encode_message(accounts, blockhash, ixs) do
    [
      create_header(accounts),
      CompactArray.to_iolist(Enum.map(accounts, & &1.key)),
      blockhash,
      CompactArray.to_iolist(encode_instructions(ixs, accounts))
    ]
    |> :erlang.list_to_binary()
  end

  defp create_header(accounts) do
    accounts
    |> Enum.reduce(
      {0, 0, 0},
      &{
        unary(&1.signer?) + elem(&2, 0),
        unary(&1.signer? && !&1.writable?) + elem(&2, 1),
        unary(!&1.signer? && !&1.writable?) + elem(&2, 2)
      }
    )
    |> Tuple.to_list()
  end

  defp unary(result?), do: if(result?, do: 1, else: 0)

  defp encode_instructions(ixs, accounts) do
    account_idxs = index_accounts(accounts)

    Enum.map(ixs, fn %{accounts: accounts, program: program, data: data} ->
      [
        Map.get(account_idxs, program),
        CompactArray.to_iolist(Enum.map(accounts, &Map.get(account_idxs, &1.key))),
        CompactArray.to_iolist(data)
      ]
    end)
  end

  defp reorder_signers(signers, accounts) do
    account_idxs = index_accounts(accounts)
    Enum.sort_by(signers, &Map.get(account_idxs, elem(&1, 1)))
  end

  defp index_accounts(accounts) do
    Enum.into(Enum.with_index(accounts, &{&1.key, &2}), %{})
  end

  defp sign({secret, pk}, message), do: Ed25519.signature(message, secret, pk)
end
