defmodule Solana.TransactionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Solana.{Transaction, Instruction, Account, CompactArray}

  defp pk({_secret, pubkey}), do: pubkey

  defp deserialize_tx(tx) do
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

  describe "to_binary" do
    test "fails if there's no blockhash" do
      payer = Solana.keypair()
      program = Solana.keypair() |> pk()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{signer?: true, writable?: true, key: pk(payer)}
        ]
      }

      tx = %Transaction{payer: pk(payer), instructions: [ix], signers: [payer]}
      assert Transaction.to_binary(tx) == {:error, :no_blockhash}
    end

    test "fails if there's no payer" do
      blockhash = Solana.keypair() |> pk()
      program = Solana.keypair() |> pk()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: blockhash}
        ]
      }

      tx = %Transaction{instructions: [ix], blockhash: blockhash}
      assert Transaction.to_binary(tx) == {:error, :no_payer}
    end

    test "fails if there's no instructions" do
      payer = Solana.keypair()
      blockhash = Solana.keypair() |> pk()
      tx = %Transaction{payer: pk(payer), blockhash: blockhash}
      assert Transaction.to_binary(tx) == {:error, :no_instructions}
    end

    test "fails if an instruction doesn't have a program" do
      blockhash = Solana.keypair() |> pk()
      payer = Solana.keypair()

      ix = %Instruction{
        accounts: [
          %Account{key: pk(payer), writable?: true, signer?: true}
        ]
      }

      tx = %Transaction{
        payer: pk(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer]
      }

      assert capture_log(fn -> Transaction.to_binary(tx) end) =~ "index 0"
    end

    test "fails if a signer is missing or if there's unnecessary signers" do
      blockhash = Solana.keypair() |> pk()
      program = Solana.keypair() |> pk()
      payer = Solana.keypair()
      signer = Solana.keypair()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: pk(payer), writable?: true, signer?: true}
        ]
      }

      tx = %Transaction{payer: pk(payer), instructions: [ix], blockhash: blockhash}
      assert Transaction.to_binary(tx) == {:error, :mismatched_signers}

      assert Transaction.to_binary(%{tx | signers: [payer, signer]}) ==
               {:error, :mismatched_signers}
    end

    test "places accounts in order (payer first)" do
      payer = Solana.keypair()
      signer = Solana.keypair()
      read_only = Solana.keypair()
      program = Solana.keypair() |> pk()
      blockhash = Solana.keypair() |> pk()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{signer?: true, key: pk(read_only)},
          %Account{signer?: true, writable?: true, key: pk(signer)},
          %Account{signer?: true, writable?: true, key: pk(payer)}
        ]
      }

      tx = %Transaction{
        payer: pk(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer, signer, read_only]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      message = deserialize_tx(tx_bin)

      assert [pk(payer), pk(signer), pk(read_only)] ==
               message
               |> Map.get(:accounts)
               |> Enum.map(& &1.key)
               |> Enum.take(3)
    end

    test "payer is writable and a signer" do
      payer = Solana.keypair()
      read_only = Solana.keypair()
      program = Solana.keypair() |> pk()
      blockhash = Solana.keypair() |> pk()

      ix = %Instruction{
        program: program,
        accounts: [%Account{key: pk(payer)}, %Account{key: pk(read_only)}]
      }

      tx = %Transaction{
        payer: pk(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      message = deserialize_tx(tx_bin)

      [actual_payer | _] = Map.get(message, :accounts)

      assert actual_payer.key == pk(payer)
      assert actual_payer.writable?
      assert actual_payer.signer?
    end

    test "sets up the header correctly" do
      payer = Solana.keypair()
      writable = Solana.keypair()
      signer = Solana.keypair()
      read_only = Solana.keypair()
      program = Solana.keypair() |> pk()
      blockhash = Solana.keypair() |> pk()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: pk(read_only)},
          %Account{writable?: true, key: pk(writable)},
          %Account{signer?: true, key: pk(signer)},
          %Account{signer?: true, writable?: true, key: pk(payer)}
        ]
      }

      tx = %Transaction{
        payer: pk(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer, signer]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      message = deserialize_tx(tx_bin)

      # 2 signers, one read-only signer, 2 read-only non-signers (read_only and
      # program)
      assert message.header == [2, 1, 2]
    end

    test "dedups signatures and accounts" do
      from = Solana.keypair()
      to = Solana.keypair()
      program = Solana.keypair() |> pk()
      blockhash = Solana.keypair() |> pk()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: pk(to)},
          %Account{signer?: true, writable?: true, key: pk(from)}
        ]
      }

      tx = %Transaction{
        payer: pk(from),
        instructions: [ix, ix],
        blockhash: blockhash,
        signers: [from]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      message = deserialize_tx(tx_bin)

      assert [_] = message.signatures
      assert length(message.accounts) == 3
    end
  end
end
