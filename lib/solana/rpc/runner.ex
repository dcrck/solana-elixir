defmodule Solana.RPC.Runner do
  use GenStage

  # API
  def start_link(config), do: GenStage.start_link(__MODULE__, config)

  def send(client = %Tesla.Client{}, requests) do
    Tesla.post(client, "/", Solana.RPC.Request.encode(requests))
  end

  # GenStage callbacks
  def init(config) do
    {:consumer, Solana.rpc_client(config), subscribe_to: [Solana.RPC.RateLimiter]}
  end

  def handle_events(events, _from, client) do
    events
    |> Enum.reduce(%{}, fn {from, request}, batches ->
      Map.update(batches, from, [request], &[request | &1])
    end)
    |> Enum.each(fn {from, requests} ->
      GenStage.reply(from, Solana.RPC.Runner.send(client, requests))
    end)

    {:noreply, [], client}
  end
end
