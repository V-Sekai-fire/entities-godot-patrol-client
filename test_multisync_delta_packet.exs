#!/usr/bin/env elixir

# Generate a delta sync packet in MultiplayerSynchronizer format
# This can be decoded by Godot's MultiplayerSynchronizer

require Logger

alias SpatialNodeStoreMultiplayerSync.Encoder

# Create changed nodes (simulating delta sync)
changed_nodes = %{
  "test_node" => %{
    "node_type" => "Node3D",
    "node_name" => "TestNode",
    "transform" => %{"origin" => %{"x" => 1.0, "y" => 2.0, "z" => 3.0}},
    "properties" => %{"velocity" => %{"x" => 1.0, "y" => 0.0, "z" => 0.0}}
  }
}

# Indexes bitmask (indicating which properties changed)
# For this test, assume property at index 0 changed
indexes = 0x0000000000000001

Logger.info("=== Generating MultiplayerSynchronizer Delta Sync Packet ===")
Logger.info("")

# Encode using our Encoder
binary_packet = Encoder.encode_delta_sync(changed_nodes, indexes)

Logger.info("Generated packet: #{byte_size(binary_packet)} bytes")
Logger.info("")

# Verify packet structure
<<command::8, delta_data::binary>> = binary_packet

Logger.info("Packet Structure:")
Logger.info("  Command: 0x#{String.pad_leading(Integer.to_string(command, 16), 2, "0")}")
Logger.info("  Delta Data: #{byte_size(delta_data)} bytes")
Logger.info("")

# Verify delta data structure
if byte_size(delta_data) >= 16 do
  <<net_id::32-little, indexes_val::64-little, data_size::32-little, variant_data::binary>> =
    delta_data

  Logger.info("Delta Data Structure:")
  Logger.info("  Net ID: #{net_id}")
  Logger.info("  Indexes: 0x#{String.pad_leading(Integer.to_string(indexes_val, 16), 16, "0")}")
  Logger.info("  Data Size: #{data_size}")
  Logger.info("  Variant Data: #{byte_size(variant_data)} bytes")
  Logger.info("")

  # Write to file for Godot to decode
  script_dir = Path.dirname(__ENV__.file)
  output_file = Path.join(script_dir, "elixir_delta_sync_packet.bin")
  File.write!(output_file, binary_packet)

  Logger.info("✅ Delta sync packet written to: #{output_file}")
  Logger.info("")
  Logger.info("Now run test_multisync_compatibility.gd in Godot to verify")
  Logger.info("MultiplayerSynchronizer can decode this packet")
else
  Logger.error("❌ Delta data too small")
  System.halt(1)
end

