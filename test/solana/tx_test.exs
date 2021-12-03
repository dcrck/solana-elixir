defmodule Solana.TransactionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import Solana, only: [pubkey!: 1]

  alias Solana.{Transaction, Instruction, Account}

  describe "to_binary/1" do
    test "fails if there's no blockhash" do
      payer = Solana.keypair()
      program = Solana.keypair() |> pubkey!()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{signer?: true, writable?: true, key: pubkey!(payer)}
        ]
      }

      tx = %Transaction{payer: pubkey!(payer), instructions: [ix], signers: [payer]}
      assert Transaction.to_binary(tx) == {:error, :no_blockhash}
    end

    test "fails if there's no payer" do
      blockhash = Solana.keypair() |> pubkey!()
      program = Solana.keypair() |> pubkey!()

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
      blockhash = Solana.keypair() |> pubkey!()
      tx = %Transaction{payer: pubkey!(payer), blockhash: blockhash}
      assert Transaction.to_binary(tx) == {:error, :no_instructions}
    end

    test "fails if an instruction doesn't have a program" do
      blockhash = Solana.keypair() |> pubkey!()
      payer = Solana.keypair()

      ix = %Instruction{
        accounts: [
          %Account{key: pubkey!(payer), writable?: true, signer?: true}
        ]
      }

      tx = %Transaction{
        payer: pubkey!(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer]
      }

      assert capture_log(fn -> Transaction.to_binary(tx) end) =~ "index 0"
    end

    test "fails if a signer is missing or if there's unnecessary signers" do
      blockhash = Solana.keypair() |> pubkey!()
      program = Solana.keypair() |> pubkey!()
      payer = Solana.keypair()
      signer = Solana.keypair()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: pubkey!(payer), writable?: true, signer?: true}
        ]
      }

      tx = %Transaction{payer: pubkey!(payer), instructions: [ix], blockhash: blockhash}
      assert Transaction.to_binary(tx) == {:error, :mismatched_signers}

      assert Transaction.to_binary(%{tx | signers: [payer, signer]}) ==
               {:error, :mismatched_signers}
    end

    test "places accounts in order (payer first)" do
      payer = Solana.keypair()
      signer = Solana.keypair()
      read_only = Solana.keypair()
      program = Solana.keypair() |> pubkey!()
      blockhash = Solana.keypair() |> pubkey!()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{signer?: true, key: pubkey!(read_only)},
          %Account{signer?: true, writable?: true, key: pubkey!(signer)},
          %Account{signer?: true, writable?: true, key: pubkey!(payer)}
        ]
      }

      tx = %Transaction{
        payer: pubkey!(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer, signer, read_only]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      {_, extras} = Transaction.parse(tx_bin)

      assert [pubkey!(payer), pubkey!(signer), pubkey!(read_only)] ==
               extras
               |> Keyword.get(:accounts)
               |> Enum.map(& &1.key)
               |> Enum.take(3)
    end

    test "payer is writable and a signer" do
      payer = Solana.keypair()
      read_only = Solana.keypair()
      program = Solana.keypair() |> pubkey!()
      blockhash = Solana.keypair() |> pubkey!()

      ix = %Instruction{
        program: program,
        accounts: [%Account{key: pubkey!(payer)}, %Account{key: pubkey!(read_only)}]
      }

      tx = %Transaction{
        payer: pubkey!(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      {_, extras} = Transaction.parse(tx_bin)

      [actual_payer | _] = Keyword.get(extras, :accounts)

      assert actual_payer.key == pubkey!(payer)
      assert actual_payer.writable?
      assert actual_payer.signer?
    end

    test "sets up the header correctly" do
      payer = Solana.keypair()
      writable = Solana.keypair()
      signer = Solana.keypair()
      read_only = Solana.keypair()
      program = Solana.keypair() |> pubkey!()
      blockhash = Solana.keypair() |> pubkey!()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: pubkey!(read_only)},
          %Account{writable?: true, key: pubkey!(writable)},
          %Account{signer?: true, key: pubkey!(signer)},
          %Account{signer?: true, writable?: true, key: pubkey!(payer)}
        ]
      }

      tx = %Transaction{
        payer: pubkey!(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer, signer]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      {_, extras} = Transaction.parse(tx_bin)

      # 2 signers, one read-only signer, 2 read-only non-signers (read_only and
      # program)
      assert Keyword.get(extras, :header) == <<2, 1, 2>>
    end

    test "dedups signatures and accounts" do
      from = Solana.keypair()
      to = Solana.keypair()
      program = Solana.keypair() |> pubkey!()
      blockhash = Solana.keypair() |> pubkey!()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: pubkey!(to)},
          %Account{signer?: true, writable?: true, key: pubkey!(from)}
        ]
      }

      tx = %Transaction{
        payer: pubkey!(from),
        instructions: [ix, ix],
        blockhash: blockhash,
        signers: [from]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      {_, extras} = Transaction.parse(tx_bin)

      assert [_] = Keyword.get(extras, :signatures)
      assert length(Keyword.get(extras, :accounts)) == 3
    end
  end

  describe "parse/1" do
    test "cannot parse an empty string" do
      assert :error = Transaction.parse("")
    end

    test "cannot parse an improperly encoded transaction" do
      payer = Solana.keypair()
      signer = Solana.keypair()
      read_only = Solana.keypair()
      program = Solana.keypair() |> pubkey!()
      blockhash = Solana.keypair() |> pubkey!()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{signer?: true, key: pubkey!(read_only)},
          %Account{signer?: true, writable?: true, key: pubkey!(signer)},
          %Account{signer?: true, writable?: true, key: pubkey!(payer)}
        ]
      }

      tx = %Transaction{
        payer: pubkey!(payer),
        instructions: [ix],
        blockhash: blockhash,
        signers: [payer, signer, read_only]
      }

      {:ok, <<_::8, clipped_tx::binary>>} = Transaction.to_binary(tx)
      assert :error = Transaction.parse(clipped_tx)
    end

    test "can parse a properly encoded tranaction" do
      from = Solana.keypair()
      to = Solana.keypair()
      program = Solana.keypair() |> pubkey!()
      blockhash = Solana.keypair() |> pubkey!()

      ix = %Instruction{
        program: program,
        accounts: [
          %Account{key: pubkey!(to)},
          %Account{signer?: true, writable?: true, key: pubkey!(from)}
        ],
        data: <<1, 2, 3>>
      }

      tx = %Transaction{
        payer: pubkey!(from),
        instructions: [ix, ix],
        blockhash: blockhash,
        signers: [from]
      }

      {:ok, tx_bin} = Transaction.to_binary(tx)
      {actual, extras} = Transaction.parse(tx_bin)

      assert [_signature] = Keyword.get(extras, :signatures)

      assert actual.payer == pubkey!(from)
      assert actual.instructions == [ix, ix]
      assert actual.blockhash == blockhash
    end
  end

  describe "decode/1" do
    test "fails for signatures which are too short" do
      encoded = B58.encode58(Enum.into(1..63, <<>>, &<<&1::8>>))
      assert {:error, _} = Transaction.decode(encoded)
      assert {:error, _} = Transaction.decode("12345")
    end

    test "fails for signatures which are too long" do
      encoded = B58.encode58(<<3, 0::64*8>>)
      assert {:error, _} = Transaction.decode(encoded)
    end

    test "fails for signatures which aren't base58-encoded" do
      assert {:error, _} =
               Transaction.decode(
                 "0x300000000000000000000000000000000000000000000000000000000000000000000"
               )

      assert {:error, _} =
               Transaction.decode(
                 "0x300000000000000000000000000000000000000000000000000000000000000"
               )

      assert {:error, _} =
               Transaction.decode(
                 "135693854574979916511997248057056142015550763280047535983739356259273198796800000"
               )
    end

    test "works for regular signatures" do
      assert {:ok, <<3, 0::63*8>>} =
               Transaction.decode(
                 "4Umk1E47BhUNBHJQGJto6i5xpATqVs8UxW11QjpoVnBmiv7aZJyG78yVYj99SrozRa9x7av8p3GJmBuzvhpUHDZ"
               )
    end
  end

  describe "decode!/1" do
    test "throws for signatures which aren't base58-encoded" do
      assert_raise ArgumentError, fn ->
        Transaction.decode!(
          "0x300000000000000000000000000000000000000000000000000000000000000000000"
        )
      end

      assert_raise ArgumentError, fn ->
        Transaction.decode!("0x300000000000000000000000000000000000000000000000000000000000000")
      end

      assert_raise ArgumentError, fn ->
        Transaction.decode!(
          "135693854574979916511997248057056142015550763280047535983739356259273198796800000"
        )
      end
    end

    test "works for regular signatures" do
      assert <<3, 0::63*8>> ==
               Transaction.decode!(
                 "4Umk1E47BhUNBHJQGJto6i5xpATqVs8UxW11QjpoVnBmiv7aZJyG78yVYj99SrozRa9x7av8p3GJmBuzvhpUHDZ"
               )
    end
  end
end
