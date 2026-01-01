#!/usr/bin/env elixir

# Verify that our implementation matches the documented format in
# docs/MULTIPLAYER_SYNCHRONIZER_BINARY_FORMAT.md
#
# This test validates specific examples from the documentation to ensure
# our encoder produces the exact format documented.

require Logger

import Bitwise

alias SpatialNodeStoreMultiplayerSync.VariantEncoder
alias SpatialNodeStoreMultiplayerSync.VariantTypes

Logger.info("=== Verifying Documentation Format ===")
Logger.info("Testing that our implementation matches docs/MULTIPLAYER_SYNCHRONIZER_BINARY_FORMAT.md")
Logger.info("")

# Test cases from documentation
test_cases = [
  # NIL
  {
    :nil,
    nil,
    <<0x00, 0x00, 0x00, 0x00>>,
    "NIL: Header only (4 bytes) = 0x00000000"
  },
  # BOOL (true)
  {
    :bool_true,
    true,
    <<0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00>>,
    "BOOL: Header (0x00000001) + Value (0x00000001 for true)"
  },
  # BOOL (false)
  {
    :bool_false,
    false,
    <<0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>,
    "BOOL: Header (0x00000001) + Value (0x00000000 for false)"
  },
  # INT (32-bit)
  {
    :int_32,
    42,
    <<0x02, 0x00, 0x00, 0x00, 0x2A, 0x00, 0x00, 0x00>>,
    "INT (32-bit): Header (0x00000002) + Value (0x0000002A = 42)"
  },
  # INT (64-bit) - large value
  {
    :int_64,
    9_223_372_036_854_775_807,
    nil,  # Will check header flag instead
    "INT (64-bit): Header with FLAG_64 + 8-byte value"
  },
  # FLOAT (32-bit)
  {
    :float_32,
    3.14,
    nil,  # Will verify approximate value
    "FLOAT (32-bit): Header (0x00000003) + IEEE 754 float"
  },
  # STRING "hello"
  {
    :string_hello,
    "hello",
    <<0x04, 0x00, 0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x68, 0x65, 0x6C, 0x6C, 0x6F, 0x00, 0x00, 0x00>>,
    "STRING: Header (0x00000004) + Length (5) + 'hello' + padding"
  },
  # VECTOR3(1.0, 2.0, 3.0)
  {
    :vector3_example,
    {1.0, 2.0, 3.0},
    <<0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x40, 0x40>>,
    "VECTOR3: Header (0x00000009) + X(1.0) + Y(2.0) + Z(3.0)"
  },
  # QUATERNION
  {
    :quaternion_example,
    {0.0, 0.0, 0.0, 1.0},
    nil,  # Will verify structure
    "QUATERNION: Header (0x0000000F) + X + Y + Z + W"
  },
  # DICTIONARY {"key": "value"}
  {
    :dictionary_example,
    %{"key" => "value"},
    nil,  # Will verify structure
    "DICTIONARY: Header (0x0000001B) + Size + Key-Value pairs"
  },
  # ARRAY [1, 2, 3]
  {
    :array_example,
    [1, 2, 3],
    nil,  # Will verify structure
    "ARRAY: Header (0x0000001C) + Size + Elements"
  }
]

# Run tests
total_tests = length(test_cases)

{pass_count, fail_count} =
  Enum.reduce(test_cases, {0, 0}, fn {test_name, value, expected_binary, description},
                                     {pass_acc, fail_acc} ->
    Logger.info("Test: #{test_name}")
    Logger.info("  Description: #{description}")

    encoded = VariantEncoder.encode_variant(value)

    {new_pass, new_fail} =
      case expected_binary do
        nil ->
          # For complex types, verify structure
          case test_name do
            :int_64 ->
              # Check for 64-bit flag
              <<header::32-little, _rest::binary>> = encoded
              has_flag = (header &&& 0x00010000) != 0
              is_64bit = byte_size(encoded) == 12

              if has_flag && is_64bit do
                Logger.info("  ✅ PASS: 64-bit INT with FLAG_64")
                {1, 0}
              else
                Logger.error("  ❌ FAIL: Expected 64-bit INT with FLAG_64")
                {0, 1}
              end

            :float_32 ->
              # Verify float encoding
              <<header::32-little, float_val::32-float-little>> = encoded
              is_close = abs(float_val - 3.14) < 0.01

              if header == VariantTypes.variant_float() && is_close do
                Logger.info("  ✅ PASS: FLOAT encoded correctly (#{float_val})")
                {1, 0}
              else
                Logger.error("  ❌ FAIL: FLOAT encoding incorrect")
                {0, 1}
              end

            :quaternion_example ->
              # Verify quaternion structure
              <<header::32-little, _x::32-float-little, _y::32-float-little, _z::32-float-little,
                w::32-float-little>> = encoded

              if header == VariantTypes.variant_quaternion() && abs(w - 1.0) < 0.01 do
                Logger.info("  ✅ PASS: QUATERNION encoded correctly")
                {1, 0}
              else
                Logger.error("  ❌ FAIL: QUATERNION encoding incorrect")
                {0, 1}
              end

            :dictionary_example ->
              # Verify dictionary structure
              <<header::32-little, size::32-little, _rest::binary>> = encoded

              if header == VariantTypes.variant_dictionary() && size == 1 do
                Logger.info("  ✅ PASS: DICTIONARY encoded correctly (size=#{size})")
                {1, 0}
              else
                Logger.error("  ❌ FAIL: DICTIONARY encoding incorrect")
                {0, 1}
              end

            :array_example ->
              # Verify array structure
              <<header::32-little, size::32-little, _rest::binary>> = encoded

              if header == VariantTypes.variant_array() && size == 3 do
                Logger.info("  ✅ PASS: ARRAY encoded correctly (size=#{size})")
                {1, 0}
              else
                Logger.error("  ❌ FAIL: ARRAY encoding incorrect")
                {0, 1}
              end

            _ ->
              Logger.info("  ⚠️  SKIP: No verification for #{test_name}")
              {0, 0}
          end

        _ ->
          # Exact binary match
          if encoded == expected_binary do
            Logger.info("  ✅ PASS: Binary matches documentation exactly")
            {1, 0}
          else
            Logger.error("  ❌ FAIL: Binary mismatch")
            Logger.error("    Expected: #{inspect(expected_binary, base: :hex)}")
            Logger.error("    Got:      #{inspect(encoded, base: :hex)}")
            {0, 1}
          end
      end

    Logger.info("")
    {pass_acc + new_pass, fail_acc + new_fail}
  end)

Logger.info("=== Test Results ===")
Logger.info("Total tests: #{total_tests}")
Logger.info("Passed: #{pass_count}")
Logger.info("Failed: #{fail_count}")
Logger.info("Skipped: #{total_tests - pass_count - fail_count}")

if fail_count == 0 do
  Logger.info("")
  Logger.info("✅ All documentation format tests PASSED")
  Logger.info("   Our implementation matches docs/MULTIPLAYER_SYNCHRONIZER_BINARY_FORMAT.md")
else
  Logger.error("")
  Logger.error("❌ Some tests FAILED")
  Logger.error("   Please update the implementation or documentation")
  System.halt(1)
end

