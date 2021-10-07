defmodule Solana.KeyTest do
  use ExUnit.Case, async: true

  alias Solana.Key

  describe "decode/1" do
    test "fails for keys which are too short" do
      encoded = B58.encode58(Enum.into(1..31, <<>>, &<<&1::8>>))
      assert {:error, :invalid_key} = Key.decode(encoded)
      assert {:error, :invalid_key} = Key.decode("12345")
    end

    test "fails for keys which are too long" do
      encoded = B58.encode58(<<3, 0::32*8>>)
      assert {:error, :invalid_key} = Key.decode(encoded)
    end

    test "fails for keys which aren't base58-encoded" do
      assert_raise ArgumentError, fn ->
        Key.decode("0x300000000000000000000000000000000000000000000000000000000000000000000")
      end

      assert_raise ArgumentError, fn ->
        Key.decode("0x300000000000000000000000000000000000000000000000000000000000000")
      end

      assert_raise ArgumentError, fn ->
        Key.decode(
          "135693854574979916511997248057056142015550763280047535983739356259273198796800000"
        )
      end
    end

    test "works for the default key" do
      assert {:ok, <<0::32*8>>} = Key.decode("11111111111111111111111111111111")
    end

    test "works for regular keys" do
      assert {:ok, <<3, 0::31*8>>} = Key.decode("CiDwVBFgWV9E5MvXWoLgnEgn2hK7rJikbvfWavzAQz3")
    end
  end

  describe "with_seed/3" do
    test "works as expected" do
      expected = Key.decode!("9h1HyLCW5dZnBVap8C5egQ9Z6pHyjsh5MNy83iPqqRuq")
      default = <<0::32*8>>
      assert {:ok, ^expected} = Key.with_seed(default, "limber chicken: 4/45", default)
    end
  end

  describe "derive_address/2" do
    setup do
      [program_id: Key.decode!("BPFLoader1111111111111111111111111111111111")]
    end

    test "works with strings as seeds", %{program_id: program_id} do
      [
        {"3gF2KMe9KiC6FNVBmfg9i267aMPvK37FewCip4eGBFcT", ["", <<1>>]},
        {"HwRVBufQ4haG5XSgpspwKtNd3PC9GM9m1196uJW36vds", ["Talking", "Squirrels"]},
        {"7ytmC1nT1xY4RfxCV2ZgyA7UakC93do5ZdyhdF3EtPj7", ["☉"]}
      ]
      |> Enum.each(fn {encoded, seeds} ->
        assert Key.decode(encoded) == Key.derive_address(seeds, program_id)
      end)
    end

    test "works with public keys and strings as seeds", %{program_id: program_id} do
      key = Key.decode!("SeedPubey1111111111111111111111111111111111")

      expected = Key.decode("GUs5qLUfsEHkcMB9T38vjr18ypEhRuNWiePW2LoK4E3K")
      assert Key.derive_address([key], program_id) == expected
      assert Key.derive_address(["Talking"], program_id) != expected
    end

    test "does not work when seeds are too long", %{program_id: program_id} do
      assert {:error, :invalid_seeds} = Key.derive_address([<<0::33*8>>], program_id)
    end

    test "does not lop off leading zeros" do
      seeds = [
        Key.decode!("H4snTKK9adiU15gP22ErfZYtro3aqR9BTMXiH3AwiUTQ"),
        <<2::little-size(64)>>
      ]

      program_id = Key.decode!("4ckmDgGdxQoPDLUkDT3vHgSAkzA3QRdNq5ywwY4sUSJn")

      assert Key.decode("12rqwuEgBYiGhBrDJStCiqEtzQpTTiZbh7teNVLuYcFA") ==
               Key.derive_address(seeds, program_id)
    end
  end

  describe "find_address/2" do
    test "finds a program address" do
      program_id = Key.decode!("BPFLoader1111111111111111111111111111111111")
      {:ok, address, nonce} = Key.find_address([""], program_id)
      assert {:ok, ^address} = Key.derive_address(["", nonce], program_id)
    end
  end
end
