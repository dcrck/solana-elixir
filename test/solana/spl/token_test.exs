defmodule Solana.SPL.TokenTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3, keypairs: 1]
  import Solana, only: [pubkey!: 1]

  alias Solana.{RPC, Transaction, SPL.Token}

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = RPC.client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    [tracker: tracker, client: client, payer: payer]
  end

  describe "init/1" do
    test "initializes a token account", %{client: client, payer: payer, tracker: tracker} do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
        signers: [payer, mint, token],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{
               owner: pubkey!(owner),
               mint: pubkey!(mint),
               initialized?: true,
               frozen?: false,
               native?: false,
               amount: 0
             } == Token.from_account_info(token_info)
    end
  end

  describe "approve/1" do
    test "approves a delegate to transfer tokens from an account", %{
      client: client,
      tracker: tracker,
      payer: payer
    } do
      [mint, token, auth, owner, delegate] = keypairs(5)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.approve(
            source: pubkey!(token),
            delegate: pubkey!(delegate),
            owner: pubkey!(owner),
            amount: 123
          )
        ],
        signers: [payer, mint, token, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{
               owner: pubkey!(owner),
               mint: pubkey!(mint),
               delegate: pubkey!(delegate),
               delegated_amount: 123,
               initialized?: true,
               frozen?: false,
               native?: false,
               amount: 0
             } == Token.from_account_info(token_info)
    end

    test "approves when checking mint and decimals", %{
      client: client,
      tracker: tracker,
      payer: payer
    } do
      [mint, token, auth, owner, delegate] = keypairs(5)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.approve(
            source: pubkey!(token),
            delegate: pubkey!(delegate),
            owner: pubkey!(owner),
            amount: 123,
            checked?: true,
            decimals: 0,
            mint: pubkey!(mint)
          )
        ],
        signers: [payer, mint, token, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{
               owner: pubkey!(owner),
               mint: pubkey!(mint),
               delegate: pubkey!(delegate),
               delegated_amount: 123,
               initialized?: true,
               frozen?: false,
               native?: false,
               amount: 0
             } == Token.from_account_info(token_info)
    end
  end

  describe "revoke/1" do
    test "revokes a delegate to prevent transfer of tokens from an account", %{
      client: client,
      tracker: tracker,
      payer: payer
    } do
      [mint, token, auth, owner, delegate] = keypairs(5)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.approve(
            source: pubkey!(token),
            delegate: pubkey!(delegate),
            owner: pubkey!(owner),
            amount: 123
          ),
          Token.revoke(
            source: pubkey!(token),
            owner: pubkey!(owner)
          )
        ],
        signers: [payer, mint, token, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{
               owner: pubkey!(owner),
               mint: pubkey!(mint),
               delegate: nil,
               delegated_amount: 0,
               initialized?: true,
               frozen?: false,
               native?: false,
               amount: 0
             } == Token.from_account_info(token_info)
    end
  end

  describe "set_authority/1" do
    test "can set an token account's authority", %{client: client, payer: payer, tracker: tracker} do
      [mint, token, auth, owner, new_owner] = keypairs(5)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.set_authority(
            account: pubkey!(token),
            authority: pubkey!(owner),
            new_authority: pubkey!(new_owner),
            type: :owner
          )
        ],
        signers: [payer, mint, token, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{
               owner: pubkey!(new_owner),
               mint: pubkey!(mint),
               initialized?: true,
               frozen?: false,
               native?: false,
               amount: 0
             } == Token.from_account_info(token_info)
    end
  end

  describe "mint_to/1" do
    test "can mint tokens to a token account", %{client: client, payer: payer, tracker: tracker} do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.mint_to(
            token: pubkey!(token),
            mint: pubkey!(mint),
            authority: pubkey!(auth),
            amount: 42
          )
        ],
        signers: [payer, mint, token, auth],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

    test "can mint tokens when checking mint/decimals", %{
      client: client,
      payer: payer,
      tracker: tracker
    } do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.mint_to(
            token: pubkey!(token),
            mint: pubkey!(mint),
            authority: pubkey!(auth),
            amount: 42,
            checked?: true,
            decimals: 0
          )
        ],
        signers: [payer, mint, token, auth],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

  describe "transfer/1" do
    test "can transfer tokens between two token accounts", %{
      client: client,
      payer: payer,
      tracker: tracker
    } do
      [mint, from, to, auth, owner] = keypairs(5)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
            new: pubkey!(from)
          ),
          Token.init(
            balance: token_balance,
            payer: pubkey!(payer),
            mint: pubkey!(mint),
            owner: pubkey!(owner),
            new: pubkey!(to)
          ),
          Token.mint_to(
            token: pubkey!(from),
            mint: pubkey!(mint),
            authority: pubkey!(auth),
            amount: 15
          ),
          Token.transfer(
            from: pubkey!(from),
            to: pubkey!(to),
            owner: pubkey!(owner),
            amount: 5
          )
        ],
        signers: [payer, mint, from, to, auth, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
          commitment: "confirmed",
          timeout: 1_000
        )

      assert {:ok, from_info} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(from),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )

      assert {:ok, to_info} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(to),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )

      assert %Token{amount: 10} = Token.from_account_info(from_info)
      assert %Token{amount: 5} = Token.from_account_info(to_info)
    end

    test "can transfer tokens when checking mint/decimals", %{
      client: client,
      payer: payer,
      tracker: tracker
    } do
      [mint, from, to, auth, owner] = keypairs(5)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
            new: pubkey!(from)
          ),
          Token.init(
            balance: token_balance,
            payer: pubkey!(payer),
            mint: pubkey!(mint),
            owner: pubkey!(owner),
            new: pubkey!(to)
          ),
          Token.mint_to(
            token: pubkey!(from),
            mint: pubkey!(mint),
            authority: pubkey!(auth),
            amount: 15,
            checked?: true,
            decimals: 0
          ),
          Token.transfer(
            from: pubkey!(from),
            to: pubkey!(to),
            owner: pubkey!(owner),
            amount: 5,
            checked?: true,
            mint: pubkey!(mint),
            decimals: 0
          )
        ],
        signers: [payer, mint, from, to, auth, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
          commitment: "confirmed",
          timeout: 1_000
        )

      assert {:ok, from_info} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(from),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )

      assert {:ok, to_info} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(to),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )

      assert %Token{amount: 10} = Token.from_account_info(from_info)
      assert %Token{amount: 5} = Token.from_account_info(to_info)
    end
  end

  describe "burn/1" do
    test "can burn tokens from a token account", %{client: client, payer: payer, tracker: tracker} do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.mint_to(
            token: pubkey!(token),
            mint: pubkey!(mint),
            authority: pubkey!(auth),
            amount: 42
          ),
          Token.burn(
            token: pubkey!(token),
            mint: pubkey!(mint),
            owner: pubkey!(owner),
            amount: 2
          )
        ],
        signers: [payer, mint, token, auth, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{amount: 40} = Token.from_account_info(token_info)
    end

    test "can burn tokens when checking mint/decimals", %{
      client: client,
      payer: payer,
      tracker: tracker
    } do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.mint_to(
            token: pubkey!(token),
            mint: pubkey!(mint),
            authority: pubkey!(auth),
            amount: 42,
            checked?: true,
            decimals: 0
          ),
          Token.burn(
            token: pubkey!(token),
            mint: pubkey!(mint),
            owner: pubkey!(owner),
            amount: 2,
            checked?: true,
            decimals: 0
          )
        ],
        signers: [payer, mint, token, auth, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{amount: 40} = Token.from_account_info(token_info)
    end
  end

  describe "close_account/1" do
    test "closes a token account", %{client: client, payer: payer, tracker: tracker} do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
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
          ),
          Token.close_account(
            to_close: pubkey!(token),
            destination: pubkey!(payer),
            authority: pubkey!(owner)
          )
        ],
        signers: [payer, mint, token, owner],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
          commitment: "confirmed",
          timeout: 1_000
        )

      assert {:ok, nil} =
               RPC.send(
                 client,
                 RPC.Request.get_account_info(pubkey!(token),
                   commitment: "confirmed",
                   encoding: "jsonParsed"
                 )
               )
    end
  end

  describe "freeze/1" do
    test "freezes a token account", %{client: client, payer: payer, tracker: tracker} do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          Token.Mint.init(
            balance: mint_balance,
            payer: pubkey!(payer),
            authority: pubkey!(auth),
            freeze_authority: pubkey!(auth),
            new: pubkey!(mint),
            decimals: 0
          ),
          Token.init(
            balance: token_balance,
            payer: pubkey!(payer),
            mint: pubkey!(mint),
            owner: pubkey!(owner),
            new: pubkey!(token)
          ),
          Token.freeze(
            to_freeze: pubkey!(token),
            mint: pubkey!(mint),
            authority: pubkey!(auth)
          )
        ],
        signers: [payer, mint, token, auth],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{frozen?: true} = Token.from_account_info(token_info)
    end
  end

  describe "thaw/1" do
    test "thaws a frozen token account", %{client: client, payer: payer, tracker: tracker} do
      [mint, token, auth, owner] = keypairs(4)

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.Mint.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_minimum_balance_for_rent_exemption(Token.byte_size(),
          commitment: "confirmed"
        ),
        RPC.Request.get_recent_blockhash(commitment: "confirmed")
      ]

      [{:ok, mint_balance}, {:ok, token_balance}, {:ok, %{"blockhash" => blockhash}}] =
        RPC.send(client, tx_reqs)

      tx = %Transaction{
        instructions: [
          Token.Mint.init(
            balance: mint_balance,
            payer: pubkey!(payer),
            authority: pubkey!(auth),
            freeze_authority: pubkey!(auth),
            new: pubkey!(mint),
            decimals: 0
          ),
          Token.init(
            balance: token_balance,
            payer: pubkey!(payer),
            mint: pubkey!(mint),
            owner: pubkey!(owner),
            new: pubkey!(token)
          ),
          Token.freeze(
            to_freeze: pubkey!(token),
            mint: pubkey!(mint),
            authority: pubkey!(auth)
          ),
          Token.thaw(
            to_thaw: pubkey!(token),
            mint: pubkey!(mint),
            authority: pubkey!(auth)
          )
        ],
        signers: [payer, mint, token, auth],
        blockhash: blockhash,
        payer: pubkey!(payer)
      }

      {:ok, _signatures} =
        RPC.send_and_confirm(client, tracker, tx,
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

      assert %Token{frozen?: false} = Token.from_account_info(token_info)
    end
  end
end
