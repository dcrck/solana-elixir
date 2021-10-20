defmodule Solana.SystemProgramTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3]
  import Solana, only: [pubkey!: 1]

  alias Solana.{SystemProgram, RPC, Transaction}

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = Solana.rpc_client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    [tracker: tracker, client: client, payer: payer]
  end

  describe "create_account/1" do
    test "can create account", %{tracker: tracker, client: client, payer: payer} do
      new = Solana.keypair()
      request_opts = [commitment: "confirmed"]

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(0, request_opts),
        RPC.Request.get_recent_blockhash(request_opts)
      ]

      [{:ok, lamports}, {:ok, %{"blockhash" => blockhash}}] = RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          SystemProgram.create_account(
            lamports: lamports,
            space: 0,
            program_id: SystemProgram.id(),
            from: pubkey!(payer),
            new: pubkey!(new)
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      assert {:ok, %{"lamports" => ^lamports}} =
               RPC.send(client, RPC.Request.get_account_info(pubkey!(new), request_opts))
    end
  end

  describe "transfer/1" do
    test "can transfer lamports to an account", %{tracker: tracker, client: client, payer: payer} do
      new = Solana.keypair()
      space = 0

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(space, commitment: "confirmed"),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
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
          SystemProgram.transfer(
            lamports: 1_000,
            from: pubkey!(payer),
            to: pubkey!(new)
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      expected = 1000 + lamports

      assert {:ok, %{"lamports" => ^expected}} =
               RPC.send(client, RPC.Request.get_account_info(pubkey!(new), commitment: "confirmed", encoding: "jsonParsed"))
    end
  end

  describe "assign/1" do
    test "can assign a new program ID to an account", %{tracker: tracker, client: client, payer: payer} do
      new = Solana.keypair()
      space = 0

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(space, commitment: "confirmed"),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
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
          SystemProgram.assign(
            account: pubkey!(new),
            program_id: Solana.SPL.Token.id()
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      {:ok, account_info} = RPC.send(client, RPC.Request.get_account_info(pubkey!(new), commitment: "confirmed", encoding: "jsonParsed"))

      assert pubkey!(account_info["owner"]) == Solana.SPL.Token.id()
    end
  end

  describe "allocate/1" do
    test "can allocate space to an account", %{tracker: tracker, client: client, payer: payer} do
      new = Solana.keypair()
      space = 0
      new_space = 10

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(new_space, commitment: "confirmed"),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
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
          SystemProgram.allocate(
            account: pubkey!(new),
            space: new_space
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      {:ok, %{"data" => [data, "base64"]}} =
        RPC.send(client, RPC.Request.get_account_info(pubkey!(new), commitment: "confirmed", encoding: "jsonParsed"))

      assert byte_size(Base.decode64!(data)) == new_space
    end
  end
end
