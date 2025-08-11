defmodule Solana.TestValidator do
  @moduledoc """
  A [Solana Test Validator](https://docs.solana.com/developing/test-validator)
  managed by an Elixir process. This allows you to run unit tests as if you had
  the `solana-test-validator` tool running in another process.

  ## Requirements

  Since `Solana.TestValidator` uses the `solana-test-validator` binary, you'll
  need to have the [Solana tool
  suite](https://docs.solana.com/cli/install-solana-cli-tools) installed.

  ## How to Use

  You can use the `Solana.TestValidator` directly or in a supervision tree.

  To use it directly, add the following lines to the beginning of your
  `test/test_helper.exs` file:

  ```elixir
  alias Solana.TestValidator
  {:ok, validator} = TestValidator.start_link(ledger: "/tmp/test-ledger")
  ExUnit.after_suite(fn _ -> TestValidator.stop(validator) end)
  ```

  This will start and stop the `solana-test-validator` before and after your
  tests run.

  ### In a supervision tree

  Alternatively, you can add it to your application's supervision tree during
  tests. Modify your `mix.exs` file to make the current environment available to
  your application:

  ```elixir
  def application do
    [mod: {MyApp, env: Mix.env()}]
  end
  ```

  Then, adjust your application's `children` depending on the environment:

  ```elixir
  defmodule MyApp do
    use Application

    def start(_type, env: env) do
      Supervisor.start_link(children(env), strategy: :one_for_one)
    end

    defp children(:test) do
      [
        {Solana.TestValidator, ledger: "/tmp/test_ledger"},
        # ... other children
      ]
    end

    defp children(_) do
      # ...other children
    end
  end
  ```

  ### Options

  You can pass any of the **long-form** options you would pass to a
  `solana-test-validator` here.

  For example, to add your own program to the validator, set the `bpf_program`
  option as the path to your program's [build
  artifact](https://docs.solana.com/developing/on-chain-programs/developing-rust#how-to-build).
  See `Solana.TestValidator.start_link/1` for more details.
  """
  use GenServer
  require Logger

  @schema [
    bind_address: [type: :string, default: "0.0.0.0"],
    bpf_program: [type: {:or, [:string, {:list, :string}]}],
    clone: [type: {:custom, Solana, :pubkey, []}],
    config: [type: :string, default: Path.expand("~/.config/solana/cli/config.yml")],
    dynamic_port_range: [type: :string, default: "8000-10000"],
    faucet_port: [type: :pos_integer, default: 9900],
    faucet_sol: [type: :pos_integer, default: 1_000_000],
    gossip_host: [type: :string, default: "127.0.0.1"],
    gossip_port: [type: :pos_integer],
    url: [type: :string],
    ledger: [type: :string, default: "test-ledger"],
    limit_ledger_size: [type: :pos_integer, default: 10_000],
    mint: [type: {:custom, Solana, :pubkey, []}],
    rpc_port: [type: :pos_integer, default: 8899],
    slots_per_epoch: [type: :pos_integer],
    warp_slot: [type: :string]
  ]

  @doc """
  Starts a `Solana.TestValidator` process linked to the current process.

  This process runs and monitors a `solana-test-validator` in the background.

  ## Options

  #{NimbleOptions.docs(@schema)}
  """
  def start_link(config) do
    case NimbleOptions.validate(config, @schema) do
      {:ok, opts} -> GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      error -> error
    end
  end

  @doc """
  Stops a `Solana.TestValidator` process.

  Should be called when you want to stop the `solana-test-validator`.
  """
  def stop(validator), do: GenServer.stop(validator, :normal)

  @doc """
  Gets the state of a `Solana.TestValidator` process.

  This is useful when you want to check the latest output of the
  `solana-test-validator`.
  """
  def get_state(validator), do: :sys.get_state(validator)

  # Callbacks
  @doc false
  def init(opts) do
    with ex_path when not is_nil(ex_path) <- System.find_executable("solana-test-validator"),
         ledger = Keyword.get(opts, :ledger),
         true <- File.exists?(Path.dirname(ledger)) do
      Process.flag(:trap_exit, true)

      port =
        Port.open({:spawn_executable, wrapper_path()}, [
          :binary,
          :exit_status,
          args: [ex_path | to_arg_list(opts)]
        ])

      Port.monitor(port)
      {:ok, %{port: port, latest_output: nil, exit_status: nil, ledger: ledger}}
    else
      false ->
        Logger.error("requested ledger directory does not exist")
        {:stop, :no_dir}

      nil ->
        Logger.error("solana-test-validator executable not found, make sure it's in your PATH")
        {:stop, :no_validator}
    end
  end

  defp to_arg_list(args) do
    args
    |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
    |> Enum.map(&handle_multiples/1)
    |> List.flatten()
    |> Enum.map(fn {k, v} -> ["--", String.replace(k, "_", "-"), " ", to_string(v), " "] end)
    |> IO.iodata_to_binary()
    |> String.trim()
    |> String.split()
  end

  defp handle_multiples({name, list}) when is_list(list) do
    Enum.map(list, &{name, &1})
  end

  defp handle_multiples(other), do: other

  @doc false
  def terminate(reason, %{port: port}) do
    os_pid = port |> Port.info() |> Keyword.get(:os_pid)
    # if reason == :normal, do: File.rm_rf(ledger)
    Logger.info("** stopped solana-test-validator (pid #{os_pid}): #{inspect(reason)}")
    :normal
  end

  @doc false
  def handle_info({port, {:data, text}}, state = %{port: port}) do
    {:noreply, %{state | latest_output: String.trim(text)}}
  end

  @doc false
  def handle_info({port, {:exit_status, status}}, state = %{port: port}) do
    {:noreply, %{state | exit_status: status}}
  end

  @doc false
  def handle_info({:DOWN, _ref, :port, _port, :normal}, state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:EXIT, _port, :normal}, state) do
    {:noreply, state}
  end

  @doc false
  def handle_info(other, state) do
    Logger.info("unhandled message: #{inspect(other)}")
    {:noreply, state}
  end

  defp wrapper_path() do
    Path.expand(Path.join(Path.dirname(__ENV__.file), "./bin/wrapper-unix"))
  end
end
