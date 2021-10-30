# Solana

The unofficial Elixir package for interacting with the
[Solana](https://solana.com) blockchain.

> Note that this README refers to the master branch of `solana`, not the latest
> released version on Hex. See [the documentation](https://hexdocs.pm/solana)
> for the documentation of the version you're using.

## Installation

Add `solana` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:solana, "~> 0.1.0"}
  ]
end
```

## Documentation

- [JSON-RPC API client](#json-rpc-api-client)
  - [Using a custom HTTP client](#using-a-custom-http-client)
- [On-chain program interaction](#solana-program-interaction)
- [Writing a custom program client](#writing-a-custom-program-client)
  - [Testing custom programs](#testing-custom-programs)

## JSON-RPC API Client

`solana` provides a simple interface for interacting with Solana's [JSON-RPC
API](https://docs.solana.com/developing/clients/jsonrpc-api). Here's an example
of requesting an airdrop to a new Solana account via the `requestAirdrop`
method:

```elixir
key = Solana.keypair() |> Solana.pubkey!()
client = Solana.RPC.client(network: "localhost")
{:ok, signature} = Solana.RPC.send(client, Solana.RPC.Request.request_airdrop(key, 1))

Solana.Transaction.check(signature) # {:ok, ^signature}
```

To see the full list of supported methods, check the `Solana.RPC.Request`
module.

### Using a custom HTTP client

Since this module uses `Tesla` for its API client, you can use whichever
HTTP client you wish, just be sure to include it in your dependencies:

```elixir
def deps do
  [
    # Gun, for example
    {:gun, "~> 1.3"},
    {:idna, "~> 6.0"},
    {:castore, "~> 0.1"},
    # SSL verification
    {:ssl_verify_hostname, "~> 1.0"},
  ]
end
```

Then, specify the corresponding `Tesla.Adapter` when creating your client:

```elixir
client = Solana.RPC.client(network: "localhost", adapter: {Tesla.Adapter.Gun, certificates_verification: true})
```

See the `Solana.RPC` module for more details about which options are available
when creating an API client.

## On-chain program interaction

Since `solana`'s JSON-RPC API client supports `sendTransaction`, you can use it
to interact with on-chain Solana programs. `solana` provides utilities to craft
transactions, send them, and confirm them on-chain. It also includes the
`Solana.SystemProgram` module, which allows you to create
[SystemProgram](https://docs.solana.com/developing/runtime-facilities/programs#system-program)
instructions.

Also check out the `solana_spl` package
[documentation](https://hexdocs.pm/solana_spl) to interact with the [Solana
Program Library](https://spl.solana.com).

## Writing a custom program client

By providing an interface for the `Solana.SystemProgram`, `solana` provides
guidelines for how to build interfaces to your own programs. For more examples,
see the [`solana_spl` package](https://hexdocs.pm/solana_spl).

### Testing custom programs

Once you've built your custom program's client, you should probably write some
tests for it. `solana` provides example tests for the `Solana.SystemProgram` in
`test/solana/system_program_test.exs`, along with an Elixir-managed [Solana Test
Validator](https://docs.solana.com/developing/test-validator) process to test
your program locally. See `Solana.TestValidator` for more details about how to
set this up.
