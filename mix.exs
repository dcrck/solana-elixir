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

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # specifies which paths to compile per environment
  def elixirc_paths(:test), do: ["lib", "test/support"]
  def elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # base client
      {:tesla, "~> 1.4.0"},
      # json library
      {:jason, ">= 1.0.0"},
      # public keys
      {:ed25519, "~> 1.3"},
      # base58 encoding
      {:b58, "~> 1.0.2"},
      # validating parameters
      {:nimble_options, "~> 0.3.0"}
    ]
  end
end
