defmodule Solana.Helpers do
  @moduledoc false
  def validate(params, schema) do
    case NimbleOptions.validate(params, schema) do
      {:ok, validated} -> {:ok, Enum.into(validated, %{})}
      error -> error
    end
  end

  def chunk(string, size), do: chunk(string, size, [])

  def chunk(<<>>, _size, acc), do: Enum.reverse(acc)

  def chunk(string, [size | sizes], acc) when byte_size(string) > size do
    <<c::size(size)-binary, rest::binary>> = string
    chunk(rest, sizes, [c | acc])
  end

  def chunk(string, size, acc) when byte_size(string) > size do
    <<c::size(size)-binary, rest::binary>> = string
    chunk(rest, size, [c | acc])
  end

  def chunk(leftover, size, acc) do
    chunk(<<>>, size, [leftover | acc])
  end
end
