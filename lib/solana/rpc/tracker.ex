defmodule Solana.RPC.Tracker do
  @moduledoc """
  A GenServer you can use to track the status of transaction signatures.

  ## Example

      iex> key = Solana.keypair() |> Solana.pubkey!()
      iex> {:ok, tracker} = Solana.RPC.Tracker.start_link(network: "localhost")
      iex> client = Solana.rpc_client(network: "localhost")
      iex> {:ok, tx} = Solana.RPC.send(client, Solana.RPC.Request.request_airdrop(key, 1))
      iex> Solana.Tracker.start_tracking(tracker, tx)
      iex> receive do
      ...>   {:ok, [^tx]} -> IO.puts("confirmed!")
      ...> end
      confirmed!

  """
  use GenServer

  alias Solana.RPC

  @doc """
  Starts a `Solana.RPC.Tracker` process linked to the current process.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Starts tracking a transaction signature or list of transaction signatures.

  Sends messages back to the calling process as transactions from the list
  are confirmed. Stops tracking automatically once transactions have been
  confirmed.
  """
  def start_tracking(tracker, signatures, opts) do
    GenServer.cast(tracker, {:track, List.wrap(signatures), opts, self()})
  end

  @doc false
  def init(opts) do
    {:ok, %{client: Solana.rpc_client(opts), t: Keyword.get(opts, :t, 500)}}
  end

  @doc false
  def handle_cast({:track, signatures, opts, from}, state) do
    Process.send_after(self(), {:check, signatures, opts, from}, 0)
    {:noreply, state}
  end

  @doc false
  def handle_info({:check, signatures, opts, from}, state) do
    request = RPC.Request.get_signature_statuses(signatures)
    commitment = Keyword.get(opts, :commitment, "finalized")

    {:ok, results} = RPC.send(state.client, request)

    mapped_results = signatures |> Enum.zip(results) |> Enum.into(%{})

    {_failed, not_failed} =
      Enum.split_with(signatures, fn signature ->
        result = Map.get(mapped_results, signature)
        !is_nil(result) && !is_nil(result["err"])
      end)

    {done, to_retry} =
      Enum.split_with(not_failed, fn signature ->
        result = Map.get(mapped_results, signature)
        !is_nil(result) && commitment_done?(result, commitment)
      end)

    if done != [], do: send(from, {:ok, done})
    if to_retry != [], do: Process.send_after(self(), {:check, to_retry, opts, from}, state.t)

    {:noreply, state}
  end

  defp commitment_done?(%{"confirmationStatus" => "finalized"}, _), do: true
  defp commitment_done?(%{"confirmationStatus" => "confirmed"}, "finalized"), do: false
  defp commitment_done?(%{"confirmationStatus" => "confirmed"}, _), do: true
  defp commitment_done?(%{"confirmationStatus" => "processed"}, "processed"), do: true
  defp commitment_done?(%{"confirmationStatus" => "processed"}, _), do: false
end
