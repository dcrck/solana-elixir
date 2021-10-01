defmodule Solana.RPC.RateLimiter do
  use GenStage

  # API
  def start_link(_), do: GenStage.start_link(__MODULE__, :ok, name: __MODULE__)

  # GenStage callbacks
  def init(:ok), do: {:producer_consumer, %{}, subscribe_to: [Solana.RPC.Client]}

  def handle_subscribe(:producer, opts, from, producers) do
    limit = Keyword.get(opts, :max_demand, 100)
    interval = Keyword.get(opts, :interval, 10_000)

    producers =
      producers
      |> Map.put(from, {limit, interval})
      |> ask_and_schedule(from)

    {:manual, producers}
  end

  def handle_subscribe(:consumer, _opts, _from, consumers) do
    {:automatic, consumers}
  end

  def handle_cancel(_, from, producers) do
    {:noreply, [], producers |> Map.delete(from)}
  end

  def handle_events(events, _from, producers) do
    {:noreply, events, producers}
  end

  def handle_info({:ask, from}, producers) do
    {:noreply, [], ask_and_schedule(producers, from)}
  end

  defp ask_and_schedule(producers, from) do
    case producers do
      %{^from => {limit, interval}} ->
        GenStage.ask(from, limit)
        Process.send_after(self(), {:ask, from}, interval)
        producers

      %{} ->
        producers
    end
  end
end
