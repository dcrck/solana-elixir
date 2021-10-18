defmodule Solana.MixProject do
  use Mix.Project

  def project do
    [
      app: :solana,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def elixirc_paths(:test), do: ["lib", "test/support"]
  def elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # base client
      {:tesla, "~> 1.4.0"},
      # json library
      {:jason, ">= 1.0.0"},
      # keys and signatures (use this one until my changes get merged)
      {:ed25519, git: "git://github.com/dcrck/ed25519_ex.git"},
      # base58 encoding
      {:basefiftyeight, "~> 0.1.0"},
      # validating parameters (use this one until my changes get merged)
      {:nimble_options, git: "git://github.com/dcrck/nimble_options.git"}
    ]
  end
end
