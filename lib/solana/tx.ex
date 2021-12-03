defmodule Solana.Transaction do
  @moduledoc """
  Functions for building and encoding Solana
  [transactions](https://docs.solana.com/developing/programming-model/transactions)
  """
  require Logger
  alias Solana.{Account, CompactArray, Instruction}

  @typedoc """
  All the details needed to encode a transaction.
  """
  @type t :: %__MODULE__{
          payer: Solana.key() | nil,
          blockhash: binary | nil,
          instructions: [Instruction.t()],
          signers: [Solana.keypair()]
        }

  @typedoc """
  The possible errors encountered when encoding a transaction.
  """
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
  decodes a base58-encoded signature and returns it in a tuple.

  If it fails, return an error tuple.
  """
  @spec decode(encoded :: binary) :: {:ok, binary} | {:error, binary}
  def decode(encoded) when is_binary(encoded) do
    case B58.decode58(encoded) do
      {:ok, decoded} -> check(decoded)
      _ -> {:error, "invalid signature"}
    end
  end

  def decode(_), do: {:error, "invalid signature"}

  @doc """
  decodes a base58-encoded signature and returns it.

  Throws an `ArgumentError` if it fails.
  """
  @spec decode!(encoded :: binary) :: binary
  def decode!(encoded) when is_binary(encoded) do
    case decode(encoded) do
      {:ok, key} ->
        key

      {:error, _} ->
        raise ArgumentError, "invalid signature input: #{encoded}"
    end
  end

  @doc """
  Checks to see if a transaction's signature is valid.

  Returns `{:ok, signature}` if it is, and an error tuple if it isn't.
  """
  @spec check(binary) :: {:ok, binary} | {:error, :invalid_signature}
  def check(signature)
  def check(<<signature::binary-64>>), do: {:ok, signature}
  def check(_), do: {:error, :invalid_signature}

  @doc """
  Encodes a `t:Solana.Transaction.t/0` into a [binary
  format](https://docs.solana.com/developing/programming-model/transactions#anatomy-of-a-transaction)

  Returns `{:ok, encoded_transaction}` if the transaction was successfully
  encoded, or an error tuple if the encoding failed -- plus more error details
  via `Logger.error/1`.
  """
  @spec to_binary(tx :: t) :: {:ok, binary()} | {:error, encoding_err()}
  def to_binary(%__MODULE__{payer: nil}), do: {:error, :no_payer}
  def to_binary(%__MODULE__{blockhash: nil}), do: {:error, :no_blockhash}
  def to_binary(%__MODULE__{instructions: []}), do: {:error, :no_instructions}

  def to_binary(tx = %__MODULE__{instructions: ixs, signers: signers}) do
    with {:ok, ixs} <- check_instructions(List.flatten(ixs)),
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
      {:error, :no_program, idx} ->
        Logger.error("Missing program id on instruction at index #{idx}")
        {:error, :no_program}

      {:error, message, idx} ->
        Logger.error("error compiling instruction at index #{idx}: #{inspect(message)}")
        {:error, message}

      false ->
        {:error, :mismatched_signers}
    end
  end

  defp check_instructions(ixs) do
    ixs
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, ixs}, fn
      {{:error, message}, idx}, _ -> {:halt, {:error, message, idx}}
      {%{program: nil}, idx}, _ -> {:halt, {:error, :no_program, idx}}
      _, acc -> {:cont, acc}
    end)
  end

  # https://docs.solana.com/developing/programming-model/transactions#account-addresses-format
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

  # https://docs.solana.com/developing/programming-model/transactions#message-format
  defp encode_message(accounts, blockhash, ixs) do
    [
      create_header(accounts),
      CompactArray.to_iolist(Enum.map(accounts, & &1.key)),
      blockhash,
      CompactArray.to_iolist(encode_instructions(ixs, accounts))
    ]
    |> :erlang.list_to_binary()
  end

  # https://docs.solana.com/developing/programming-model/transactions#message-header-format
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

  # https://docs.solana.com/developing/programming-model/transactions#instruction-format
  defp encode_instructions(ixs, accounts) do
    idxs = index_accounts(accounts)

    Enum.map(ixs, fn ix = %Instruction{} ->
      [
        Map.get(idxs, ix.program),
        CompactArray.to_iolist(Enum.map(ix.accounts, &Map.get(idxs, &1.key))),
        CompactArray.to_iolist(ix.data)
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

  @doc """
  Parses a `t:Solana.Transaction.t/0` from data encoded in Solana's [binary
  format](https://docs.solana.com/developing/programming-model/transactions#anatomy-of-a-transaction)

  Returns `{transaction, extras}` if the transaction was successfully
  parsed, or `:error` if the provided binary could not be parsed. `extras`
  is a keyword list containing information about the encoded transaction,
  namely:

  - `:header` - the [transaction message
  header](https://docs.solana.com/developing/programming-model/transactions#message-header-format)
  - `:accounts` - an [ordered array of
  accounts](https://docs.solana.com/developing/programming-model/transactions#account-addresses-format)
  - `:signatures` - a [list of signed copies of the transaction
  message](https://docs.solana.com/developing/programming-model/transactions#signatures)
  """
  @spec parse(encoded :: binary) :: {t(), keyword} | :error
  def parse(encoded) do
    with {signatures, message, _} <- CompactArray.decode_and_split(encoded, 64),
         <<header::binary-size(3), contents::binary>> <- message,
         {account_keys, hash_and_ixs, key_count} <- CompactArray.decode_and_split(contents, 32),
         <<blockhash::binary-size(32), ix_data::binary>> <- hash_and_ixs,
         {:ok, instructions} <- extract_instructions(ix_data) do
      tx_accounts = derive_accounts(account_keys, key_count, header)
      indices = Enum.into(Enum.with_index(tx_accounts, &{&2, &1}), %{})

      {
        %__MODULE__{
          payer: tx_accounts |> List.first() |> Map.get(:key),
          blockhash: blockhash,
          instructions:
            Enum.map(instructions, fn {program, accounts, data} ->
              %Instruction{
                data: if(data == "", do: nil, else: :binary.list_to_bin(data)),
                program: Map.get(indices, program) |> Map.get(:key),
                accounts: Enum.map(accounts, &Map.get(indices, &1))
              }
            end)
        },
        [
          accounts: tx_accounts,
          header: header,
          signatures: signatures
        ]
      }
    else
      _ -> :error
    end
  end

  defp extract_instructions(data) do
    with {ix_data, ix_count} <- CompactArray.decode_and_split(data),
         {reversed_ixs, ""} <- extract_instructions(ix_data, ix_count) do
      {:ok, Enum.reverse(reversed_ixs)}
    else
      error -> error
    end
  end

  defp extract_instructions(data, count) do
    Enum.reduce_while(1..count, {[], data}, fn _, {acc, raw} ->
      case extract_instruction(raw) do
        {ix, rest} -> {:cont, {[ix | acc], rest}}
        _ -> {:halt, :error}
      end
    end)
  end

  defp extract_instruction(raw) do
    with <<program::8, rest::binary>> <- raw,
         {accounts, rest, _} <- CompactArray.decode_and_split(rest, 1),
         {data, rest, _} <- extract_instruction_data(rest) do
      {{program, Enum.map(accounts, &:binary.decode_unsigned/1), data}, rest}
    else
      _ -> :error
    end
  end

  defp extract_instruction_data(""), do: {"", "", 0}
  defp extract_instruction_data(raw), do: CompactArray.decode_and_split(raw, 1)

  defp derive_accounts(keys, total, header) do
    <<signers_count::8, signers_readonly_count::8, nonsigners_readonly_count::8>> = header
    {signers, nonsigners} = Enum.split(keys, signers_count)
    {signers_write, signers_read} = Enum.split(signers, signers_count - signers_readonly_count)

    {nonsigners_write, nonsigners_read} =
      Enum.split(nonsigners, total - signers_count - nonsigners_readonly_count)

    List.flatten([
      Enum.map(signers_write, &%Account{key: &1, writable?: true, signer?: true}),
      Enum.map(signers_read, &%Account{key: &1, signer?: true}),
      Enum.map(nonsigners_write, &%Account{key: &1, writable?: true}),
      Enum.map(nonsigners_read, &%Account{key: &1})
    ])
  end
end
