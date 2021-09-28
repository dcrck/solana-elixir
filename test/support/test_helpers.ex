defmodule Solana.TestHelpers do
  alias Solana.{CompactArray, Account}

  @spec deserialize_tx(tx :: binary) :: map
  def deserialize_tx(tx) do
    {signatures, message} = extract_signatures(tx)
    {header, contents} = extract_header(message)
    {account_keys, blockhash_and_instrs, num_accounts} = extract_accounts(contents)
    {blockhash, instructions} = extract_blockhash(blockhash_and_instrs)
    instructions = extract_instructions(instructions)

    accounts = derive_accounts(account_keys, num_accounts, header)

    account_idxs = Enum.into(Enum.with_index(accounts, &{&2, &1}), %{})

    %{
      header: header,
      accounts: accounts,
      signatures: signatures,
      transaction: %Solana.Transaction{
        payer: List.first(accounts),
        blockhash: blockhash,
        instructions:
          Enum.map(instructions, fn ix ->
            %Solana.Instruction{
              data: if(ix.data == "", do: nil, else: ix.data),
              program: Map.get(account_idxs, ix.program),
              accounts: Enum.map(ix.accounts, &Map.get(account_idxs, &1))
            }
          end)
      }
    }
  end

  defp extract_signatures(tx) do
    {signatures, message, _} = CompactArray.decode_and_split(tx, 64)
    {signatures, message}
  end

  defp extract_header(message) do
    <<signers::8, signers_readonly::8, nonsigners_readonly::8, contents::binary>> = message
    {[signers, signers_readonly, nonsigners_readonly], contents}
  end

  defp extract_accounts(data), do: CompactArray.decode_and_split(data, 32)

  defp extract_blockhash(data) do
    <<blockhash::binary-size(32), rest::binary>> = data
    {blockhash, rest}
  end

  defp extract_instructions(ixs_data) do
    {ixs, length} = CompactArray.decode_and_split(ixs_data)

    Enum.map(0..length, fn _ ->
      <<program::8, ixs::binary>> = ixs
      {accounts, data, _} = CompactArray.decode_and_split(ixs, 1)
      %{program: program, accounts: Enum.map(accounts, &:binary.decode_unsigned/1), data: data}
    end)
  end

  defp derive_accounts(keys, size, header) do
    [signers_count, signers_readonly_count, nonsigners_readonly_count] = header
    {signers, nonsigners} = Enum.split(keys, signers_count)
    {signers_write, signers_read} = Enum.split(signers, signers_count - signers_readonly_count)

    {nonsigners_write, nonsigners_read} =
      Enum.split(nonsigners, size - signers_count - nonsigners_readonly_count)

    List.flatten([
      Enum.map(signers_write, &%Account{key: &1, writable?: true, signer?: true}),
      Enum.map(signers_read, &%Account{key: &1, signer?: true}),
      Enum.map(nonsigners_write, &%Account{key: &1, writable?: true}),
      Enum.map(nonsigners_read, &%Account{key: &1})
    ])
  end
end
