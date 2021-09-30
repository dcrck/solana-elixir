defmodule Solana.RPC.Middleware do
  @behaviour Tesla.Middleware

  @success 200..299

  def call(env, next, _) do
    env
    |> Tesla.run(next)
    |> handle_response()
  end

  defp handle_response({:ok, response = %{status: status}})
       when status in @success do
    {:ok, response_content(response)}
  end

  defp handle_response({:ok, %{status: status}}), do: {:error, status}
  defp handle_response(other), do: other

  defp response_content(%{body: body}) when is_list(body) do
    body
    |> Enum.sort_by(&Map.get(&1, "id"))
    |> Enum.map(&json_rpc_result/1)
  end

  defp response_content(%{body: body}), do: json_rpc_result(body)

  defp json_rpc_result(%{"result" => %{"value" => value}}), do: value
  defp json_rpc_result(%{"result" => result}), do: result
  defp json_rpc_result(%{"error" => error}), do: error
end
