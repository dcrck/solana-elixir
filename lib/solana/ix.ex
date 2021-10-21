defmodule Solana.Instruction do
  alias Solana.Account

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

  def encode_data(data) do
    Enum.into(data, <<>>, &encode_value/1)
  end

  defp encode_value({value, "str"}) when is_binary(value) do
    <<byte_size(value)::little-size(32), 0::32, value::binary>>
  end

  defp encode_value({value, size}), do: encode_value({value, size, :little})
  defp encode_value({value, size, :big}), do: <<value::size(size)-big>>
  defp encode_value({value, size, :little}), do: <<value::size(size)-little>>
  defp encode_value(value) when is_binary(value), do: value
  defp encode_value(value) when is_integer(value), do: <<value>>
end
