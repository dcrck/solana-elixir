alias Solana.TestValidator
{:ok, validator} = TestValidator.start_link(ledger: "/tmp/test-ledger")
ExUnit.after_suite(fn _ -> TestValidator.stop(validator) end)
ExUnit.start()
