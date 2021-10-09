defmodule Solana.SPL.Token.MultiSigTest do
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
end
