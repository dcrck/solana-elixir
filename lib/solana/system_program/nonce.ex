defmodule Solana.SystemProgram.Nonce do
  alias Solana.{Instruction, Account, SystemProgram}
  import Solana.Helpers

  def byte_size(), do: 80

  def from_account_info(%{"data" => %{"parsed" => %{"info" => info}}}) do
    from_nonce_account_info(info)
  end

  def from_account_info(_), do: :error

  defp from_nonce_account_info(%{"authority" => authority, "blockhash" => blockhash, "feeCalculator" => calculator}) do
    %{
      authority: Solana.pubkey!(authority),
      blockhash: B58.decode58!(blockhash),
      calculator: calculator
    }
  end

  defp from_nonce_account_info(_), do: :error

  def init(opts) do
    schema = [
      nonce: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce account"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce authority"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: Solana.recent_blockhashes()},
            %Account{key: Solana.rent()}
          ],
          data: Instruction.encode_data([{6, 32}, params.authority])
        }

      error ->
        error
    end
  end

  def authorize(opts) do
    schema = [
      nonce: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce account"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce authority"
      ],
      new_authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key to set as the new nonce authority"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: params.authority, signer?: true}
          ],
          data: Instruction.encode_data([{7, 32}, params.new_authority])
        }

      error ->
        error
    end
  end

  def advance(opts) do
    schema = [
      nonce: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce account"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce authority"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: Solana.recent_blockhashes()},
            %Account{key: params.authority, signer?: true}
          ],
          data: Instruction.encode_data([{4, 32}])
        }

      error ->
        error
    end
  end

  def withdraw(opts) do
    schema = [
      nonce: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce account"
      ],
      authority: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the nonce authority"
      ],
      to: [
        type: {:custom, Solana.Key, :check, []},
        required: true,
        doc: "Public key of the account which will get the withdrawn lamports"
      ],
      lamports: [
        type: :pos_integer,
        required: true,
        doc: "Amount of lamports to transfer to the created account"
      ]
    ]

    case validate(opts, schema) do
      {:ok, params} ->
        %Instruction{
          program: SystemProgram.id(),
          accounts: [
            %Account{key: params.nonce, writable?: true},
            %Account{key: params.to, writable?: true},
            %Account{key: Solana.recent_blockhashes()},
            %Account{key: Solana.rent()},
            %Account{key: params.authority, signer?: true}
          ],
          data: Instruction.encode_data([{5, 32}, {params.lamports, 64}])
        }

      error ->
        error
    end
  end

end
