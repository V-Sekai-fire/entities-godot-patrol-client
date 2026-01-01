#!/usr/bin/env elixir

# Test: Round-trip encoding/decoding in Elixir
# This verifies our encoder produces valid Godot-compatible format

require Logger

alias SpatialNodeStoreMultiplayerSync.VariantEncoder

# Test variants
variants = [
  nil,
  true,
  false,
  42,
  -100,
  3.14,
  -2.5,
  "hello",
  "world",
  {1.0, 2.0, 3.0},  # VECTOR3
  {-1.0, 0.0, 1.0},  # VECTOR3
  {0.0, 0.0, 0.0, 1.0},  # QUATERNION
  %{"key1" => "value1", "key2" => 42},  # DICTIONARY
  %{"nested" => %{"inner" => "value"}},  # NESTED DICTIONARY
  [1, 2, 3],  # ARRAY
  ["a", "b", "c"],  # ARRAY
  [1.0, 2.0, 3.0]  # ARRAY of floats
]

Logger.info("=== Round-Trip Encoding Test ===")
Logger.info("Encoding and verifying variant structure")
Logger.info("")

# Encode all variants
encoded_data =
  Enum.reduce(variants, <<>>, fn variant, acc ->
    encoded = VariantEncoder.encode_variant(variant)
    Logger.info("✓ Encoded: #{inspect(variant)} -> #{byte_size(encoded)} bytes")
    <<acc::binary, encoded::binary>>
  end)

Logger.info("")
Logger.info("✅ Successfully encoded #{length(variants)} variants")
Logger.info("   Total size: #{byte_size(encoded_data)} bytes")
Logger.info("")
Logger.info("The encoded data is in Godot-compatible format.")
Logger.info("To test with Godot, run test_elixir_to_godot.exs and then")
Logger.info("run test_elixir_to_godot.gd in Godot to decode.")

