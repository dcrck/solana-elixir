defmodule Solana.SPL.TokenTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3]

  alias Solana.RPC

  setup_all do
    {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
    client = Solana.rpc_client(network: "localhost")
    {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

    [tracker: tracker, client: client, payer: payer]
  end

  # TODO add init/1 tests
  describe "init/1" do
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
