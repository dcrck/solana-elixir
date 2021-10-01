defmodule Solana.RPC.Client do
  use GenStage

  # API
  def start_link(_), do: GenStage.start_link(__MODULE__, :ok, name: __MODULE__)

  def send(client, requests) when is_pid(client) do
    GenStage.call(client, {:send, requests})
  end

  def send(client = %Tesla.Client{}, requests) do
    Solana.RPC.Runner.send(client, requests)
  end

  # GenStage callbacks
  def init(:ok) do
    {:producer, %{demand: 0, queue: []}}
  end

  def handle_call({:send, requests}, from, state) do
    {events, queue, demand} =
      state.queue
      |> add_to_queue(from, requests)
      |> fulfill_demand(state.demand)

    {:noreply, expand(events), %{queue: queue, demand: demand}}
  end

  def handle_demand(demand, state) do
    {events, queue, demand} =
      state.queue
      |> fulfill_demand(demand)

    {:noreply, expand(events), %{queue: queue, demand: demand}}
  end

  defp add_to_queue(queue, from, requests) do
    List.flatten([queue | [{from, List.wrap(requests)}]])
  end

  defp expand(events) do
    events
    |> Enum.map(fn {from, requests} -> Enum.map(requests, &{from, &1}) end)
    |> List.flatten()
  end

  defp fulfill_demand(queue, demand) do
    Enum.reduce_while(queue, {[], queue, demand}, fn
      {from, requests}, {to_emit, [_ | rest], demand} when length(requests) <= demand ->
        {:cont, {[{from, requests} | to_emit], rest, demand - length(requests)}}

      _, acc ->
        {:halt, acc}
    end)
  end
end
