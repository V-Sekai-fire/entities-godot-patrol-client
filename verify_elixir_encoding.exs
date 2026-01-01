#!/usr/bin/env elixir

# Verify the Elixir-encoded variants have correct structure
# This checks that the binary format matches Godot's expected format

require Logger

import Bitwise

alias SpatialNodeStoreMultiplayerSync.VariantTypes

# Helper functions
defp get_type_name(0), do: "NIL"
defp get_type_name(1), do: "BOOL"
defp get_type_name(2), do: "INT"
defp get_type_name(3), do: "FLOAT"
defp get_type_name(4), do: "STRING"
defp get_type_name(9), do: "VECTOR3"
defp get_type_name(15), do: "QUATERNION"
defp get_type_name(27), do: "DICTIONARY"
defp get_type_name(28), do: "ARRAY"
defp get_type_name(n), do: "TYPE_#{n}"

defp get_expected_size(0, _flags, _rest), do: 4  # NIL
defp get_expected_size(1, _flags, _rest), do: 8  # BOOL
defp get_expected_size(2, flags, _rest) do
  if (flags &&& 0x0001) != 0, do: 12, else: 8  # INT (64-bit or 32-bit)
end

defp get_expected_size(3, flags, _rest) do
  if (flags &&& 0x0001) != 0, do: 12, else: 8  # FLOAT (64-bit or 32-bit)
end

defp get_expected_size(4, _flags, rest) do
  if byte_size(rest) >= 4 do
    <<len::32-little, _::binary>> = rest
    pad = rem(4 - rem(len, 4), 4)
    4 + 4 + len + pad  # Header + length + data + padding
  else
    8  # Minimum (header + length)
  end
end

defp get_expected_size(9, _flags, _rest), do: 16  # VECTOR3 (4 + 12)
defp get_expected_size(15, _flags, _rest), do: 20  # QUATERNION (4 + 16)
defp get_expected_size(27, _flags, rest) do
  # DICTIONARY: header + size + key-value pairs (complex, return minimum)
  if byte_size(rest) >= 4 do
    <<size::32-little, _::binary>> = rest
    8 + (size * 16)  # Rough estimate (header + size + pairs)
  else
    8
  end
end

defp get_expected_size(28, _flags, rest) do
  # ARRAY: header + size + elements (complex, return minimum)
  if byte_size(rest) >= 4 do
    <<size::32-little, _::binary>> = rest
    8 + (size * 8)  # Rough estimate (header + size + elements)
  else
    8
  end
end

defp get_expected_size(_type, _flags, _rest), do: 4  # Default minimum

defp verify_variants(data, offset, variant_count, errors) when offset >= byte_size(data) do
  {variant_count, errors}
end

defp verify_variants(data, offset, variant_count, errors) do
  if offset + 4 > byte_size(data) do
    Logger.warning("Incomplete variant at offset #{offset}")
    {variant_count, errors}
  else
    <<header::32-little, rest::binary>> = binary_part(data, offset, byte_size(data) - offset)
    variant_type = header &&& 0xFF
    flags = (header >>> 16) &&& 0xFFFF

    new_variant_count = variant_count + 1
    type_name = get_type_name(variant_type)

    Logger.info("Variant #{new_variant_count}: Type=#{variant_type} (#{type_name}), Flags=0x#{String.pad_leading(Integer.to_string(flags, 16), 4, "0")}")

    # Verify type is valid
    new_errors =
      if variant_type > VariantTypes.variant_max() do
        errors ++ ["Variant #{new_variant_count}: Invalid type #{variant_type}"]
      else
        errors
      end

    # Calculate expected size based on type
    expected_size = get_expected_size(variant_type, flags, rest)
    actual_size = min(expected_size, byte_size(rest) + 4)

    Logger.info("  Offset: #{offset}, Expected size: #{expected_size} bytes")

    new_offset = offset + actual_size

    # Safety check
    if actual_size == 0 do
      Logger.warning("Variant size is 0, stopping")
      {new_variant_count, new_errors}
    else
      verify_variants(data, new_offset, new_variant_count, new_errors)
    end
  end
end

# Main execution
input_file = Path.join([__DIR__, "elixir_encoded_variants.bin"])

Logger.info("=== Verifying Elixir Encoded Variants ===")
Logger.info("")

if File.exists?(input_file) do
  data = File.read!(input_file)
  Logger.info("Read #{byte_size(data)} bytes from file")
  Logger.info("")

  # Verify each variant header
  {variant_count, errors} = verify_variants(data, 0, 0, [])

  Logger.info("")
  if length(errors) == 0 do
    Logger.info("✅ Verified #{variant_count} variants - all headers are valid")
  else
    Logger.error("❌ Found #{length(errors)} errors:")
    Enum.each(errors, fn error -> Logger.error("  #{error}") end)
  end
else
  Logger.error("ERROR: File not found: #{input_file}")
  Logger.error("Run test_elixir_to_godot.exs first")
  System.halt(1)
end
