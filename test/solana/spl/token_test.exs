defmodule Solana.SPL.TokenTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3]
  import Solana.SPL.TestHelpers, only: [create_mint: 3]

  alias Solana.{RPC, Transaction, SPL.Token}

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = Solana.rpc_client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    {_, auth} = Solana.keypair()
    {_, mint} = create_mint(tracker, client, payer: payer, authority: auth, decimals: 0)
    [tracker: tracker, client: client, payer: payer, auth: auth, mint: mint]
  end

  describe "init/1" do
    test "initializes a token account", %{mint: mint} = global do
      new = {_, new_pk} = Solana.keypair()
      {_, owner} = Solana.keypair()
      space = Token.byte_size()
      opts = [commitment: "confirmed"]

      tx_reqs = [
        RPC.Request.get_minimum_balance_for_rent_exemption(space, opts),
        RPC.Request.get_recent_blockhash(opts)
      ]

      [{:ok, lamports}, {:ok, %{"blockhash" => blockhash}}] = RPC.send(global.client, tx_reqs)

      tx = %Transaction{
        instructions: [
          Token.init(
            balance: lamports,
            payer: Solana.pubkey!(global.payer),
            mint: mint,
            owner: owner,
            new: new_pk
          )
        ],
        signers: [global.payer, new],
        blockhash: blockhash,
        payer: Solana.pubkey!(global.payer)
      }

      opts = [commitment: "confirmed", timeout: 1_000]
      {:ok, _signatures} = RPC.send_and_confirm(global.client, global.tracker, tx, opts)
      opts = [commitment: "confirmed", encoding: "jsonParsed"]
      assert {:ok, token} =
        RPC.send(global.client, RPC.Request.get_account_info(Solana.pubkey!(new), opts))

      assert %Token{
        owner: ^owner,
        mint: ^mint,
        initialized?: true,
        frozen?: false,
        native?: false,
        amount: 0,
      } = Token.from_account_info(token)
    end
  end

  # TODO add transfer/1 tests
  describe "transfer/1" do
  end

  # TODO add approve/1 tests
  describe "approve/1" do
  end

  # TODO add revoke/1 tests
  describe "revoke/1" do
  end

  # TODO add set_authority/1 tests
  describe "set_authority/1" do
  end

  # TODO add mint_to/1 tests
  describe "mint_to/1" do
  end

  # TODO add burn/1 tests
  describe "burn/1" do
  end

  # TODO add close_account/1 tests
  describe "close_account/1" do
  end

  # TODO add freeze/1 tests
  describe "freeze/1" do
  end

  # TODO add thaw/1 tests
  describe "thaw/1" do
  end
end
