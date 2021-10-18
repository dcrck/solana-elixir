defmodule Solana.SPL.TestHelpers do
  alias Solana.{RPC, SPL.Token, Transaction}

  def create_mint(tracker, client, opts) do
    space = Token.Mint.byte_size()

    request_opts = [commitment: "confirmed"]

    tx_reqs = [
      RPC.Request.get_minimum_balance_for_rent_exemption(space, request_opts),
      RPC.Request.get_recent_blockhash(request_opts)
    ]

    [{:ok, lamports}, {:ok, %{"blockhash" => blockhash}}] = RPC.send(client, tx_reqs)

    opts = Keyword.put_new(opts, :new, Solana.keypair())

    mint = Keyword.fetch!(opts, :new)
    payer = Keyword.fetch!(opts, :payer)

    init_opts =
      opts
      |> Keyword.take([:payer, :authority, :new, :decimals, :freeze_authority])
      |> Keyword.update!(:payer, &Solana.pubkey!/1)
      |> Keyword.update!(:new, &Solana.pubkey!/1)
      |> Keyword.put(:balance, lamports)

    tx = %Transaction{
      instructions: [Token.Mint.init(init_opts)],
      signers: [payer, mint],
      blockhash: blockhash,
      payer: Solana.pubkey!(payer)
    }

    {:ok, _} = RPC.send_and_confirm(client, tracker, tx, commitment: "confirmed", timeout: 1_000)

    mint
  end
end
