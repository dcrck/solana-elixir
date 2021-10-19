defmodule Solana.SPL.Token.MultiSigTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3, keypairs: 1]
  import Solana, only: [pubkey!: 1]

  alias Solana.{RPC, SPL.Token, Transaction}

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = Solana.rpc_client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    [tracker: tracker, client: client, payer: payer]
  end

  describe "init/1" do
    test "initializes a multi-sig account", %{client: client, payer: payer, tracker: tracker} do
      [multisig | signers] = keypairs(11)

      signers = Enum.map(signers, &pubkey!/1)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.MultiSig.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, balance}, {:ok, %{"blockhash" => blockhash}}] = RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          Token.MultiSig.init(
            balance: balance,
            payer: pubkey!(payer),
            signers: signers,
            new: pubkey!(multisig),
            signatures_required: 5
          )
        ],
        signers: [payer, multisig],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
          commitment: "confirmed",
          timeout: 1_000
        )

      assert {:ok, multisig_info} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(multisig),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )

      assert %Token.MultiSig{
               signers_required: 5,
               signers_total: 10,
               initialized?: true,
               signers: ^signers
             } = Token.MultiSig.from_account_info(multisig_info)
    end
  end
end
