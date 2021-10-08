defmodule Solana.TestHelpers do
  alias Solana.RPC

  def create_payer(tracker, client, opts \\ []) do
    payer = Solana.keypair()

    sol = Keyword.get(opts, :amount, 5)
    timeout = Keyword.get(opts, :timeout, 5_000)
    request_opts = Keyword.take(opts, [:commitment])

    {:ok, tx} = RPC.send(client, RPC.Request.request_airdrop(Solana.pubkey!(payer), sol, request_opts))
    :ok = RPC.Tracker.start_tracking(tracker, tx, request_opts)
    receive do
      {:ok, [^tx]} -> {:ok, payer}
    after
      timeout -> {:error, :timeout}
    end
  end
end
