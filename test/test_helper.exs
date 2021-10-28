alias Solana.TestValidator

extra_programs = [
  {Solana.SPL.TokenSwap, ["solana-program-library", "target", "deploy", "spl_token_swap.so"]}
]

opts = [
  ledger: "/tmp/test-ledger",
  bpf_program:
    Enum.map(extra_programs, fn {mod, path} ->
      [B58.encode58(mod.id()), Path.expand(Path.join(["deps" | path]))]
      |> Enum.join(" ")
    end)
]

{:ok, validator} = TestValidator.start_link(opts)
ExUnit.after_suite(fn _ -> TestValidator.stop(validator) end)
ExUnit.start()
