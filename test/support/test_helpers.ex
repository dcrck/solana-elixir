defmodule Solana.TestHelpers do
  @moduledoc """
  Some helper functions for testing Solana programs.
  """
  alias Solana.RPC

  @doc """
  Creates an account and airdrops some SOL to it. This is useful when creating
  other accounts and you need an account to pay the rent fees.
  """
  @spec create_payer(tracker :: pid, Tesla.Client.t(), keyword) ::
          {:ok, Solana.keypair()} | {:error, :timeout}
  def create_payer(tracker, client, opts \\ []) do
    payer = Solana.keypair()

    sol = Keyword.get(opts, :amount, 5)
    timeout = Keyword.get(opts, :timeout, 5_000)
    request_opts = Keyword.take(opts, [:commitment])

    {:ok, tx} =
      RPC.send(client, RPC.Request.request_airdrop(Solana.pubkey!(payer), sol, request_opts))

    :ok = RPC.Tracker.start_tracking(tracker, tx, request_opts)

    receive do
      {:ok, [^tx]} -> {:ok, payer}
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Generates a list of `n` keypairs.
  """
  @spec keypairs(n :: pos_integer) :: [Solana.keypair()]
  def keypairs(n) do
    Enum.map(1..n, fn _ -> Solana.keypair() end)
  end
end
