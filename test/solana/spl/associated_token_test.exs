defmodule Solana.SPL.AssociatedTokenTest do
  use ExUnit.Case, async: true

  import Solana.TestHelpers, only: [create_payer: 3]

  alias Solana.{SPL.AssociatedToken, RPC}

  describe "find_address/2" do
    test "fails if the owner is invalid" do
      assert :error = AssociatedToken.find_address(
        Solana.pubkey!("7o36UsWR1JQLpZ9PE2gn9L4SQ69CNNiWAXd4Jt7rqz9Z"),
        Solana.pubkey!("DShWnroshVbeUp28oopA3Pu7oFPDBtC1DBmPECXXAQ9n")
      )
    end

    test "finds the associated token address for a given owner and mint" do
      expected = Solana.pubkey!("DShWnroshVbeUp28oopA3Pu7oFPDBtC1DBmPECXXAQ9n")

      assert {:ok, ^expected} = AssociatedToken.find_address(
        Solana.pubkey!("7o36UsWR1JQLpZ9PE2gn9L4SQ69CNNiWAXd4Jt7rqz9Z"),
        Solana.pubkey!("B8UwBUUnKwCyKuGMbFKWaG7exYdDk2ozZrPg72NyVbfj")
      )
    end
  end

  #TODO: add create_account/1 tests
  describe "create_account/1" do
    setup_all do
      {:ok, tracker} = RPC.Tracker.start_link(network: "localhost", t: 100)
      client = Solana.rpc_client(network: "localhost")
      {:ok, payer} = create_payer(tracker, client, commitment: "confirmed")

      [tracker: tracker, client: client, payer: payer]
    end
  end
end
