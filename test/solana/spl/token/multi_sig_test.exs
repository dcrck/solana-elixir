defmodule Solana.SPL.Token.MultiSigTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3, keypairs: 1]
  import Solana, only: [pubkey!: 1]

  alias Solana.{RPC, SPL.Token, Transaction}

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = RPC.client(network: "localhost")
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

  test "can execute other instructions using a multi-sig account", %{
    client: client,
    payer: payer,
    tracker: tracker
  } do
    [mint, token, owner, auth | signers] = keypairs(14)

    signer_keys = Enum.map(signers, &pubkey!/1)

    tx_reqs = [
      RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
        commitment: "confirmed"
      ),
      RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
        commitment: "confirmed"
      ),
      RPC.Request.get_minimum_balance_for_rent_exemption(Token.MultiSig.byte_size(),
        commitment: "confirmed"
      ),
      RPC.Request.get_recent_blockhash(commitment: "confirmed")
    ]

    [
      {:ok, mint_balance},
      {:ok, token_balance},
      {:ok, multi_balance},
      {:ok, %{"blockhash" => blockhash}}
    ] = RPC.send(client, tx_reqs)

    init_tx = %Transaction{
      instructions: [
        Token.MultiSig.init(
          balance: multi_balance,
          payer: pubkey!(payer),
          signers: signer_keys,
          new: pubkey!(auth),
          signatures_required: 5
        ),
        Token.Mint.init(
          balance: mint_balance,
          payer: pubkey!(payer),
          authority: pubkey!(auth),
          new: pubkey!(mint),
          decimals: 0
        ),
        Token.init(
          balance: token_balance,
          payer: pubkey!(payer),
          mint: pubkey!(mint),
          owner: pubkey!(owner),
          new: pubkey!(token)
        )
      ],
      signers: [payer, auth, mint, token],
      blockhash: blockhash,
      payer: pubkey!(payer)
    }

    {:ok, _signatures} =
      RPC.send_and_confirm(client, tracker, init_tx,
        commitment: "confirmed",
        timeout: 1_000
      )

    mint_tx = %Transaction{
      instructions: [
        Token.mint_to(
          token: pubkey!(token),
          mint: pubkey!(mint),
          multi_signers: Enum.take(signer_keys, 5),
          authority: pubkey!(auth),
          amount: 42
        )
      ],
      signers: [payer | Enum.take(signers, 5)],
      blockhash: blockhash,
      payer: pubkey!(payer)
    }

    {:ok, _signatures} =
      RPC.send_and_confirm(client, tracker, mint_tx,
        commitment: "confirmed",
        timeout: 1_000
      )

    assert {:ok, token_info} =
             RPC.send(
               client,
               RPC.Request.get_account_info(pubkey!(token),
                 commitment: "confirmed",
                 encoding: "jsonParsed"
               )
             )

    assert %Token{amount: 42} = Token.from_account_info(token_info)
  end
end
