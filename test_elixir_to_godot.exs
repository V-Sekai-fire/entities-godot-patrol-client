#!/usr/bin/env elixir

# Test: Encode variants in Elixir for Godot to decode
# This script encodes test variants and writes them to a file that Godot can read
#
# Usage: Run from project root: mix run thirdparty/godot-multiplayer-sync-test/test_elixir_to_godot.exs

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

Logger.info("=== Test: Elixir to Godot Variant Encoding ===")
Logger.info("Encoding variants for Godot to decode")
Logger.info("")

# Encode all variants
encoded_data =
  Enum.reduce(variants, <<>>, fn variant, acc ->
    encoded = VariantEncoder.encode_variant(variant)
    Logger.info("Encoded variant: #{inspect(variant)} -> #{byte_size(encoded)} bytes")
    <<acc::binary, encoded::binary>>
  end)

# Write to file (relative to script directory)
script_dir = Path.dirname(__ENV__.file)
output_file = Path.join(script_dir, "elixir_encoded_variants.bin")
File.write!(output_file, encoded_data)

Logger.info("")
Logger.info("✅ Encoded #{length(variants)} variants to file: #{output_file}")
Logger.info("   Total size: #{byte_size(encoded_data)} bytes")
Logger.info("")
Logger.info("Now run the Godot test script to decode these variants")

