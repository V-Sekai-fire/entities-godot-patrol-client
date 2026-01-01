#!/usr/bin/env elixir

# Generate a full sync packet in MultiplayerSynchronizer format
# This can be decoded by Godot's MultiplayerSynchronizer

require Logger

alias SpatialNodeStoreMultiplayerSync.Encoder
alias SpatialNodeStoreMultiplayerSync.VariantEncoder
alias SpatialNodeStoreMultiplayerSync.MultiplayerAPICompression

# Create a test scene tree (simulating what MultiplayerSynchronizer would receive)
scene_tree = %{
  "test_node" => %{
    "node_type" => "Node3D",
    "node_name" => "TestNode",
    "transform" => %{
      "origin" => %{"x" => 1.0, "y" => 2.0, "z" => 3.0}
    },
    "properties" => %{}
  }
}

sync_net_time = 1

Logger.info("=== Generating MultiplayerSynchronizer Full Sync Packet ===")
Logger.info("")

# Encode using our Encoder (which uses MultiplayerSynchronizer format)
binary_packet = Encoder.encode_full_sync(scene_tree, sync_net_time)

Logger.info("Generated packet: #{byte_size(binary_packet)} bytes")
Logger.info("")

# Verify packet structure
<<command::8, net_time::16-little, sync_data::binary>> = binary_packet

Logger.info("Packet Structure:")
Logger.info("  Command: 0x#{String.pad_leading(Integer.to_string(command, 16), 2, "0")}")
Logger.info("  Network Time: #{net_time}")
Logger.info("  Sync Data: #{byte_size(sync_data)} bytes")
Logger.info("")

# Verify sync data structure
if byte_size(sync_data) >= 8 do
  <<net_id::32-little, data_size::32-little, variant_data::binary>> = sync_data

  Logger.info("Sync Data Structure:")
  Logger.info("  Net ID: #{net_id}")
  Logger.info("  Data Size: #{data_size}")
  Logger.info("  Variant Data: #{byte_size(variant_data)} bytes")
  Logger.info("")

  # Write to file for Godot to decode
  script_dir = Path.dirname(__ENV__.file)
  output_file = Path.join(script_dir, "elixir_full_sync_packet.bin")
  File.write!(output_file, binary_packet)

  Logger.info("✅ Full sync packet written to: #{output_file}")
  Logger.info("")
  Logger.info("Now run test_multisync_compatibility.gd in Godot to verify")
  Logger.info("MultiplayerSynchronizer can decode this packet")
else
  Logger.error("❌ Sync data too small")
  System.halt(1)
end

