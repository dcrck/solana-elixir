defmodule Solana.SPL.Helpers do
  @moduledoc false

  @doc false
  # use this until nimble_options releases v0.3.8 on hex
  def in?(number, first, last) when number in first..last do
    {:ok, number}
  end

  def in?(other, first, last) do
    {:error, "expected value in #{first}..#{last}, got: #{inspect other}"}
  end
end
