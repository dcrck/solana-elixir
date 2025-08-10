defmodule Solana.RPC.Middleware do
  @behaviour Tesla.Middleware

  @moduledoc false

  @success 200..299

  def call(env = %{body: request}, next, _) do
    env
    |> Tesla.run(next)
    |> handle_response(request)
  end

  defp handle_response({:ok, response = %{status: status}}, request)
       when status in @success do
    response_content(response, request)
  end

  defp handle_response({:ok, %{status: status}}, _), do: {:error, status}
  defp handle_response(other, _), do: other

  defp response_content(%{body: body}, requests) when is_list(body) do
    responses = body |> Enum.sort_by(& &1["id"]) |> Enum.map(&extract_result/1)

    requests
    |> Enum.sort_by(& &1.id)
    |> Enum.map(& &1.method)
    |> Enum.zip(responses)
    |> Enum.map(&decode_result/1)
  end

  defp response_content(%{body: response}, request) do
    decode_result({request.method, extract_result(response)})
  end

  defp extract_result(%{"result" => %{"value" => value}}), do: value
  defp extract_result(%{"result" => result}), do: result
  defp extract_result(other), do: other

  defp decode_result({_, %{"error" => error}}), do: {:error, error}

  defp decode_result({"requestAirdrop", airdrop_tx}) do
    {:ok, B58.decode58!(airdrop_tx)}
  end

  defp decode_result({"getSignaturesForAddress", signature_responses}) do
    responses =
      Enum.map(signature_responses, fn response ->
        update_in(response, ["signature"], &B58.decode58!/1)
      end)

    {:ok, responses}
  end

  defp decode_result({"getLatestBlockhash", blockhash_result}) do
    {:ok, update_in(blockhash_result, ["blockhash"], &B58.decode58!/1)}
  end

  defp decode_result({"getRecentBlockhash", blockhash_result}) do
    {:ok, update_in(blockhash_result, ["blockhash"], &B58.decode58!/1)}
  end

  defp decode_result({"sendTransaction", signature}) do
    {:ok, B58.decode58!(signature)}
  end

  defp decode_result({"getTransaction", %{"transaction" => tx} = result}) when is_map(tx) do
    tx =
      tx
      |> update_in(["message", "accountKeys"], &decode_b58_list/1)
      |> update_in(["message", "recentBlockhash"], &B58.decode58!/1)
      |> Map.update!("signatures", &decode_b58_list/1)

    {:ok, Map.put(result, "transaction", tx)}
  end

  defp decode_result({"getAccountInfo", %{} = result}) do
    {:ok, Map.update!(result, "owner", &B58.decode58!/1)}
  end

  # just run the decoding for getAccountInfo for each item in the list
  defp decode_result({"getMultipleAccounts", result}) when is_list(result) do
    {:ok, Enum.map(result, &elem(decode_result({"getAccountInfo", &1}), 1))}
  end

  defp decode_result({_method, result}), do: {:ok, result}

  defp decode_b58_list(list), do: Enum.map(list, &B58.decode58!/1)
end
