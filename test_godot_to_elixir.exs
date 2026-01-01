#!/usr/bin/env elixir

# Test: Decode variants encoded by Godot
# This script reads a file encoded by Godot and decodes the variants
#
# Usage: Run from project root: mix run thirdparty/godot-multiplayer-sync-test/test_godot_to_elixir.exs

require Logger

# Decoder implementation for Godot's variant binary format
# Supports decoding variants encoded by Godot for testing purposes

defmodule GodotVariantDecoder do
  @moduledoc """
  Decodes Godot's variant binary format.
  
  This is a simplified decoder for testing purposes.
  A full implementation would need to handle all variant types.
  """

  def decode_variant(data, offset \\ 0) do
    if offset >= byte_size(data) do
      {:ok, nil, offset}
    else
      # Read 32-bit header
      <<header::32-little, rest::binary>> = binary_part(data, offset, byte_size(data) - offset)
      variant_type = header &&& 0xFF
      flags = (header >> 16) &&& 0xFFFF

      case variant_type do
        0 -> decode_nil(rest, offset + 4)
        1 -> decode_bool(rest, offset + 4)
        2 -> decode_int(rest, offset + 4, flags)
        3 -> decode_float(rest, offset + 4, flags)
        4 -> decode_string(rest, offset + 4)
        9 -> decode_vector3(rest, offset + 4)
        15 -> decode_quaternion(rest, offset + 4)
        27 -> decode_dictionary(rest, offset + 4)
        28 -> decode_array(rest, offset + 4)
        _ -> {:error, :unknown_type, offset}
      end
    end
  end

  defp decode_nil(_rest, offset), do: {:ok, nil, offset}

  defp decode_bool(rest, offset) do
    <<bool_val::32-little, _::binary>> = rest
    {:ok, bool_val != 0, offset + 4}
  end

  defp decode_int(rest, offset, flags) do
    if (flags &&& 0x10000) != 0 do
      # 64-bit
      <<int_val::64-signed-little, _::binary>> = rest
      {:ok, int_val, offset + 8}
    else
      # 32-bit
      <<int_val::32-signed-little, _::binary>> = rest
      {:ok, int_val, offset + 4}
    end
  end

  defp decode_float(rest, offset, flags) do
    if (flags &&& 0x10000) != 0 do
      # 64-bit
      <<float_val::64-float-little, _::binary>> = rest
      {:ok, float_val, offset + 8}
    else
      # 32-bit
      <<float_val::32-float-little, _::binary>> = rest
      {:ok, float_val, offset + 4}
    end
  end

  defp decode_string(rest, offset) do
    <<len::32-little, rest2::binary>> = rest
    pad = rem(4 - rem(len, 4), 4)
    <<str_bytes::binary-size(len), _padding::binary-size(pad), _::binary>> = rest2
    {:ok, str_bytes, offset + 4 + len + pad}
  end

  defp decode_vector3(rest, offset) do
    <<x::32-float-little, y::32-float-little, z::32-float-little, _::binary>> = rest
    {:ok, {x, y, z}, offset + 12}
  end

  defp decode_quaternion(rest, offset) do
    <<x::32-float-little, y::32-float-little, z::32-float-little, w::32-float-little,
      _::binary>> = rest
    {:ok, {x, y, z, w}, offset + 16}
  end

  defp decode_dictionary(rest, offset) do
    <<size::32-little, rest2::binary>> = rest
    {dict, new_offset} = decode_dict_pairs(rest2, offset + 4, size, %{})
    {:ok, dict, new_offset}
  end

  defp decode_dict_pairs(_rest, offset, 0, acc), do: {acc, offset}

  defp decode_dict_pairs(rest, offset, count, acc) do
    {:ok, key, key_offset} = decode_variant(rest, 0)
    {:ok, value, value_offset} = decode_variant(rest, key_offset)
    new_offset = offset + value_offset
    new_rest = binary_part(rest, value_offset, byte_size(rest) - value_offset)
    decode_dict_pairs(new_rest, new_offset, count - 1, Map.put(acc, key, value))
  end

  defp decode_array(rest, offset) do
    <<size::32-little, rest2::binary>> = rest
    {array, new_offset} = decode_array_elements(rest2, offset + 4, size, [])
    {:ok, array, new_offset}
  end

  defp decode_array_elements(_rest, offset, 0, acc), do: {Enum.reverse(acc), offset}

  defp decode_array_elements(rest, offset, count, acc) do
    {:ok, element, element_offset} = decode_variant(rest, 0)
    new_offset = offset + element_offset
    new_rest = binary_part(rest, element_offset, byte_size(rest) - element_offset)
    decode_array_elements(new_rest, new_offset, count - 1, [element | acc])
  end
end

# Read file encoded by Godot (relative to script directory)
script_dir = Path.dirname(__ENV__.file)
input_file = Path.join(script_dir, "godot_encoded_variants.bin")

Logger.info("=== Test: Godot to Elixir Variant Decoding ===")
Logger.info("Decoding variants encoded by Godot")
Logger.info("")

if File.exists?(input_file) do
  data = File.read!(input_file)
  Logger.info("Read #{byte_size(data)} bytes from Godot-encoded file")
  Logger.info("")

  # Decode all variants
  offset = 0
  test_count = 0
  pass_count = 0

  while offset < byte_size(data) do
    case GodotVariantDecoder.decode_variant(data, offset) do
      {:ok, variant, new_offset} ->
        test_count = test_count + 1
        Logger.info("✓ Variant #{test_count}: #{inspect(variant)}")
        pass_count = pass_count + 1
        offset = new_offset

      {:error, reason, _} ->
        Logger.error("✗ Failed to decode at offset #{offset}: #{inspect(reason)}")
        break
    end
  end

  Logger.info("")
  Logger.info("Results: #{pass_count}/#{test_count} variants decoded successfully")

  if pass_count == test_count and test_count > 0 do
    Logger.info("✅ All variants decoded successfully!")
  else
    Logger.error("❌ Some variants failed to decode")
    System.halt(1)
  end
else
  Logger.error("ERROR: Could not find file: #{input_file}")
  Logger.error("Run the Godot test script first to generate the file")
  System.halt(1)
end

