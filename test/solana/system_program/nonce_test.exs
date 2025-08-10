defmodule Solana.SystemProgram.NonceTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3, keypairs: 1]
  import Solana, only: [pubkey!: 1]

  alias Solana.{SystemProgram, RPC, Transaction}

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = RPC.client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    [tracker: tracker, client: client, payer: payer]
  end

  describe "init/1" do
    test "can create a nonce account", %{tracker: tracker, client: client, payer: payer} do
      new = Solana.keypair()
      space = SystemProgram.Nonce.byte_size()

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(space, commitment: "confirmed"),
        RPC.Request.get_latest_blockhash(commitment: "confirmed")
      ]

      [{:ok, lamports}, {:ok, %{"blockhash" => blockhash}}] = RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          SystemProgram.create_account(
            lamports: lamports,
            space: space,
            program_id: SystemProgram.id(),
            from: pubkey!(payer),
            new: pubkey!(new)
          ),
          SystemProgram.Nonce.init(
            nonce: pubkey!(new),
            authority: pubkey!(payer)
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      assert {:ok, %{}} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(new),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )
    end
  end

  describe "authorize/1" do
    test "can set a new authority for a nonce account", %{
      tracker: tracker,
      client: client,
      payer: payer
    } do
      [new, auth] = keypairs(2)
      space = SystemProgram.Nonce.byte_size()

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(space, commitment: "confirmed"),
        RPC.Request.get_latest_blockhash(commitment: "confirmed")
      ]

      [{:ok, lamports}, {:ok, %{"blockhash" => blockhash}}] = RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          SystemProgram.create_account(
            lamports: lamports,
            space: space,
            program_id: SystemProgram.id(),
            from: pubkey!(payer),
            new: pubkey!(new)
          ),
          SystemProgram.Nonce.init(
            nonce: pubkey!(new),
            authority: pubkey!(payer)
          ),
          SystemProgram.Nonce.authorize(
            nonce: pubkey!(new),
            authority: pubkey!(payer),
            new_authority: pubkey!(auth)
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      {:ok, account_info} =
        RPC.send(
          client,
          RPC.Request.get_account_info(pubkey!(new),
            commitment: "confirmed",
            encoding: "jsonParsed"
          )
        )

      %{authority: authority} = SystemProgram.Nonce.from_account_info(account_info)

      assert authority == pubkey!(auth)
    end
  end

  describe "advance/1" do
    test "can change a nonce account's nonce", %{tracker: tracker, client: client, payer: payer} do
      new = Solana.keypair()
      space = SystemProgram.Nonce.byte_size()

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(space, commitment: "confirmed"),
        RPC.Request.get_latest_blockhash(commitment: "confirmed")
      ]

      [{:ok, lamports}, {:ok, %{"blockhash" => blockhash}}] = RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          SystemProgram.create_account(
            lamports: lamports,
            space: space,
            program_id: SystemProgram.id(),
            from: pubkey!(payer),
            new: pubkey!(new)
          ),
          SystemProgram.Nonce.init(
            nonce: pubkey!(new),
            authority: pubkey!(payer)
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      {:ok, info} =
        RPC.send(
          client,
          RPC.Request.get_account_info(pubkey!(new),
            commitment: "confirmed",
            encoding: "jsonParsed"
          )
        )

      tx = %Transaction{
        instructions: [
          SystemProgram.Nonce.advance(
            nonce: pubkey!(new),
            authority: pubkey!(payer)
          )
        ],
        signers: [payer],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      {:ok, info2} =
        RPC.send(
          client,
          RPC.Request.get_account_info(pubkey!(new),
            commitment: "confirmed",
            encoding: "jsonParsed"
          )
        )

      assert Map.get(SystemProgram.Nonce.from_account_info(info), :blockhash) !=
               Map.get(SystemProgram.Nonce.from_account_info(info2), :blockhash)
    end
  end

  describe "withdraw/1" do
    test "can withdraw lamports from a nonce account", %{
      tracker: tracker,
      client: client,
      payer: payer
    } do
      new = Solana.keypair()
      space = SystemProgram.Nonce.byte_size()

      tx_reqs = [
        RPC.Request.get_latest_blockhash(commitment: "confirmed")
      ]

      [{:ok, %{"blockhash" => blockhash}}] = RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          SystemProgram.create_account(
            lamports: Solana.lamports_per_sol(),
            space: space,
            program_id: SystemProgram.id(),
            from: pubkey!(payer),
            new: pubkey!(new)
          ),
          SystemProgram.Nonce.init(
            nonce: pubkey!(new),
            authority: pubkey!(payer)
          ),
          SystemProgram.Nonce.withdraw(
            nonce: pubkey!(new),
            authority: pubkey!(payer),
            to: pubkey!(payer),
            lamports: div(Solana.lamports_per_sol(), 2)
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      {:ok, info} =
        RPC.send(
          client,
          RPC.Request.get_account_info(pubkey!(new),
            commitment: "confirmed",
            encoding: "jsonParsed"
          )
        )

      assert info["lamports"] == div(Solana.lamports_per_sol(), 2)
    end
  end
end
