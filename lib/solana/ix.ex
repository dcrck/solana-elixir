defmodule Solana.Instruction do
  @moduledoc """
  Functions, types, and structures related to Solana
  [instructions](https://docs.solana.com/developing/programming-model/transactions#instructions).
  """
  alias Solana.Account

  @typedoc """
  All the details needed to encode an instruction.
  """
  @type t :: %__MODULE__{
          program: Solana.key() | nil,
          accounts: [Account.t()],
          data: binary | nil
        }

  defstruct [
    :data,
    :program,
    accounts: []
  ]

  @doc false
  def encode_data(data) do
    Enum.into(data, <<>>, &encode_value/1)
  end

  # encodes a string in Rust's expected format
  defp encode_value({value, "str"}) when is_binary(value) do
    <<byte_size(value)::little-size(32), 0::32, value::binary>>
  end

  # encodes a string in Borsh's expected format
  # https://borsh.io/#pills-specification
  defp encode_value({value, "borsh"}) when is_binary(value) do
    <<byte_size(value)::little-size(32), value::binary>>
  end

  defp encode_value({value, size}), do: encode_value({value, size, :little})
  defp encode_value({value, size, :big}), do: <<value::size(size)-big>>
  defp encode_value({value, size, :little}), do: <<value::size(size)-little>>
  defp encode_value(value) when is_binary(value), do: value
  defp encode_value(value) when is_integer(value), do: <<value>>
  defp encode_value(value) when is_boolean(value), do: <<unary(value)>>

  defp unary(val), do: if(val, do: 1, else: 0)
end
