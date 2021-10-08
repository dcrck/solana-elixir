defmodule Solana.SystemProgramTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3]

  alias Solana.{SystemProgram, RPC, Transaction}

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = Solana.rpc_client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    [tracker: tracker, client: client, payer: payer]
  end

  describe "create_account/1" do
    test "can see account changes", %{tracker: tracker, client: client, payer: payer} do
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
            from: Solana.pubkey!(payer),
            new: Solana.pubkey!(new),
          )
        ],
        signers: [payer, new],
        blockhash: blockhash,
        payer: Solana.pubkey!(payer)
      }

      {:ok, _signature} = RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

      assert {:ok, %{"lamports" => ^lamports}} =
        RPC.send(client, RPC.Request.get_account_info(Solana.pubkey!(new), request_opts))
    end
  end
end
