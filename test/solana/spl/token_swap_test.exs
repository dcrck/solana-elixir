defmodule Solana.SPL.TokenSwapTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3, keypairs: 1]
  import Solana, only: [pubkey!: 1]

  alias Solana.{Key, RPC, Transaction, SPL.Token, SPL.TokenSwap}

  @fees [
    trade_fee: {25, 10000},
    owner_trade_fee: {5, 10000},
    owner_withdraw_fee: {1, 6},
    host_fee: {2, 10}
  ]

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = RPC.client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    [tracker: tracker, client: client, payer: payer]
  end

  describe "init/1" do
    test "initializes a token swap account", %{client: client, payer: payer, tracker: tracker} do
      [swap, owner, pool_mint, pool, fee_account] = keypairs(5)
      {:ok, authority, nonce} = Key.find_address([pubkey!(swap)], TokenSwap.id())
      mints = [mint_a, mint_b] = keypairs(2)
      tokens = [token_a, token_b] = keypairs(2)

      tx_reqs = [
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
        | Enum.map([Token.Mint, Token, TokenSwap], fn mod ->
            RPC.Request.get_minimum_balance_for_rent_exemption(mod.byte_size(),
              commitment: "confirmed"
            )
          end)
      ]

      [%{"blockhash" => blockhash}, mint_balance, token_balance, swap_balance] =
        client
        |> RPC.send(tx_reqs)
        |> Enum.map(fn {:ok, result} -> result end)

      create_pool_accounts_tx = %Transaction{
        instructions: [
          Token.Mint.init(
            balance: mint_balance,
            payer: pubkey!(payer),
            authority: authority,
            new: pubkey!(pool_mint),
            decimals: 0
          ),
          Token.init(
            balance: token_balance,
            payer: pubkey!(payer),
            mint: pubkey!(pool_mint),
            owner: pubkey!(owner),
            new: pubkey!(pool)
          ),
          Token.init(
            balance: token_balance,
            payer: pubkey!(payer),
            mint: pubkey!(pool_mint),
            owner: pubkey!(owner),
            new: pubkey!(fee_account)
          )
        ],
        signers: [payer, pool_mint, fee_account, pool],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      pairs = Enum.zip(mints, tokens)

      create_tokens_tx = %Transaction{
        instructions:
          Enum.map(pairs, fn {mint, token} ->
            [
              Token.Mint.init(
                balance: mint_balance,
                payer: pubkey!(payer),
                authority: pubkey!(owner),
                new: pubkey!(mint),
                decimals: 0
              ),
              Token.init(
                balance: token_balance,
                payer: pubkey!(payer),
                mint: pubkey!(mint),
                owner: authority,
                new: pubkey!(token)
              ),
              Token.mint_to(
                token: pubkey!(token),
                mint: pubkey!(mint),
                authority: pubkey!(owner),
                amount: 1_000_000
              )
            ]
          end),
        signers: List.flatten([payer, owner, mints, tokens]),
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(
          client,
          tracker,
          [create_pool_accounts_tx, create_tokens_tx],
          commitment: "confirmed",
          timeout: 1_000
        )

      # setup is done, now create the swap
      swap_tx = %Transaction{
        instructions: [
          TokenSwap.init(
            Keyword.merge(@fees,
              payer: pubkey!(payer),
              balance: swap_balance,
              authority: authority,
              new: pubkey!(swap),
              token_a: pubkey!(token_a),
              token_b: pubkey!(token_b),
              pool: pubkey!(pool),
              pool_mint: pubkey!(pool_mint),
              fee_account: pubkey!(fee_account),
              curve: {:price, 1}
            )
          )
        ],
        signers: [payer, swap],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signature} =
        RPC.send_and_confirm(client, tracker, swap_tx,
          commitment: "confirmed",
          timeout: 1_000
        )

      assert {:ok, swap_info} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(swap),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )

      assert %{
               token_a: pubkey!(token_a),
               token_b: pubkey!(token_b),
               trade_fee: @fees[:trade_fee],
               owner_trade_fee: @fees[:owner_trade_fee],
               owner_withdraw_fee: @fees[:owner_withdraw_fee],
               host_fee: @fees[:host_fee],
               pool_mint: pubkey!(pool_mint),
               mint_a: pubkey!(mint_a),
               mint_b: pubkey!(mint_b),
               fee_account: pubkey!(fee_account),
               version: 1,
               initialized?: true,
               bump_seed: nonce,
               curve: {:price, 1}
             } == TokenSwap.from_account_info(swap_info)
    end
  end

  # TODO: add deposit_all/1 tests
  describe "deposit_all/1" do
  end

  # TODO: add deposit_all/1 tests
  describe "withdraw_all/1" do
  end

  # TODO: add deposit_all/1 tests
  describe "deposit/1" do
  end

  # TODO: add deposit_all/1 tests
  describe "withdraw/1" do
  end
end
