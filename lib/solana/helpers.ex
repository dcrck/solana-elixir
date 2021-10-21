defmodule Solana.Helpers do
  @moduledoc false
  def validate(params, schema) do
    case NimbleOptions.validate(params, schema) do
      {:ok, validated} -> {:ok, Enum.into(validated, %{})}
      error -> error
    end
  end
end
