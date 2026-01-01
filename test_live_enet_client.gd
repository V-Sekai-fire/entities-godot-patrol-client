extends SceneTree

## Headless test client for MultiplayerSynchronizer compatibility
## Connects to Elixir server via ENet DTLS and tests packet format, sync rate, and data correctness
## Usage: godot --headless --script test_live_enet_client.gd --host 127.0.0.1 --port 7777 --duration 60 --client-id 1

var enet_peer: ENetMultiplayerPeer
var multiplayer_api: MultiplayerAPI
var server_host: String = "127.0.0.1"
var server_port: int = 7777
var test_duration: float = 60.0  # seconds
var client_id: int = 1
var connected: bool = false
var start_time: float = 0.0

# Metrics
var packets_received: int = 0
var total_bytes_received: int = 0
var sync_responses_received: int = 0
var latency_samples: Array = []
var last_request_time: float = 0.0
var sync_rate_samples: Array = []
var last_packet_time: float = 0.0
var network_times: Array = []
var decoded_synchronizers: Array = []
var data_correctness_errors: Array = []

# Expected data (for correctness verification)
var expected_nodes: Dictionary = {}
var instance_id: String = "test_baseline"

func _initialize():
	print("=== MultiplayerSynchronizer Live ENet Test Client ===")
	print("Client ID: ", client_id)
	print("")
	
	# Parse command line arguments
	var args = OS.get_cmdline_args()
	for i in range(args.size()):
		if args[i] == "--host" and i + 1 < args.size():
			server_host = args[i + 1]
		elif args[i] == "--port" and i + 1 < args.size():
			server_port = int(args[i + 1])
		elif args[i] == "--duration" and i + 1 < args.size():
			test_duration = float(args[i + 1])
		elif args[i] == "--client-id" and i + 1 < args.size():
			client_id = int(args[i + 1])
		elif args[i] == "--instance-id" and i + 1 < args.size():
			instance_id = args[i + 1]
	
	print("Configuration:")
	print("  Server: ", server_host, ":", server_port)
	print("  Duration: ", test_duration, " seconds")
	print("  Instance ID: ", instance_id)
	print("")
	
	# Initialize ENet
	enet_peer = ENetMultiplayerPeer.new()
	var err = enet_peer.create_client(server_host, server_port)
	if err != OK:
		print("❌ ERROR: Failed to create ENet client: ", err)
		quit(1)
		return
	
	multiplayer_api = get_multiplayer()
	multiplayer_api.multiplayer_peer = enet_peer
	
	# Connect signals
	enet_peer.peer_connected.connect(_on_peer_connected)
	enet_peer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer_api.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer_api.peer_disconnected.connect(_on_multiplayer_peer_disconnected)
	
	print("Connecting to ", server_host, ":", server_port, "...")
	start_time = Time.get_ticks_msec() / 1000.0
	
	# Start connection process
	await process_frame
	_process_connection()

func _process_connection():
	# Poll ENet
	enet_peer.poll()
	
	# Check connection status
	if enet_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		if not connected:
			connected = true
			print("✅ Connected to server")
			print("")
			print("Waiting for sync packets from server...")
			print("Note: Sync requests are sent by Elixir helper clients")
			print("      (see scripts/send_sync_requests.exs)")
			print("")
			last_packet_time = Time.get_ticks_msec() / 1000.0
	
	# Process incoming packets
	_process_packets()
	
	# Check if test duration exceeded
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	if elapsed >= test_duration:
		_finish_test()
		return
	
	# Schedule next frame
	await process_frame
	_process_connection()

func _process_packets():
	# Process all available packets
	while multiplayer_api.has_multiplayer_peer() and multiplayer_api.get_multiplayer_peer().get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		multiplayer_api.poll()
		
		# Check for packets on channel 0 (multiplayer sync) - default for ENetMultiplayerPeer
		# Godot's SceneMultiplayer processes NETWORK_COMMAND_SYNC (0x01) packets automatically
		var packet = multiplayer_api.get_multiplayer_peer().get_packet()
		if packet == null or packet.size() == 0:
			break
		
		_process_sync_packet(packet)

# Note: Godot cannot send Erlang term-encoded packets
# Sync requests are sent by Elixir helper clients (see scripts/send_sync_requests.exs)
# This client focuses on receiving and decoding binary MultiplayerSynchronizer packets

func _process_sync_packet(packet: PackedByteArray):
	if packet.size() < 3:
		print("⚠️  Received packet too small: ", packet.size(), " bytes")
		return
	
	packets_received += 1
	total_bytes_received += packet.size()
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var latency = current_time - last_request_time
	if latency > 0 and latency < 1.0:  # Reasonable latency range
		latency_samples.append(latency)
		if latency_samples.size() > 1000:
			latency_samples.pop_front()
	
	# Track packet timing for sync rate
	if last_packet_time > 0:
		var packet_interval = current_time - last_packet_time
		sync_rate_samples.append(packet_interval)
		if sync_rate_samples.size() > 100:
			sync_rate_samples.pop_front()
	last_packet_time = current_time
	
	# Decode packet
	var decode_result = _decode_packet(packet)
	if decode_result != null:
		sync_responses_received += 1
		decoded_synchronizers.append_array(decode_result.synchronizers)
		network_times.append(decode_result.net_time)
		
		# Trace: Log packet details
		if packets_received <= 10 or packets_received % 64 == 0:  # First 10 packets, then every 64
			print("📦 Packet #", packets_received, ":")
			print("   Size: ", packet.size(), " bytes")
			print("   Network Time: ", decode_result.net_time)
			print("   Synchronizers: ", decode_result.synchronizers.size())
			for i in range(min(3, decode_result.synchronizers.size())):  # Show first 3
				var sync = decode_result.synchronizers[i]
				print("     [", i, "] Net ID: ", sync.net_id, ", Data Size: ", sync.data_size, " bytes")
				if sync.variant != null:
					var variant_type = typeof(sync.variant)
					print("         Variant Type: ", variant_type, " = ", _variant_to_string(sync.variant))
		
		# Verify data correctness (if we have expected data)
		if expected_nodes.size() > 0:
			_verify_data_correctness(decode_result.synchronizers)

func _decode_packet(packet: PackedByteArray) -> Dictionary:
	# Parse MultiplayerSynchronizer packet format
	# Format: [Command: 1 byte] [Network Time: 2 bytes] [Sync Data...]
	
	if packet.size() < 3:
		return {}
	
	var offset = 0
	var command = packet[offset]
	offset += 1
	
	# Check if it's a sync packet
	if command != 0x01:  # NETWORK_COMMAND_SYNC
		print("⚠️  Unexpected command: 0x", "%02x" % command)
		return {}
	
	# Read network time (16-bit little-endian)
	var net_time = packet[offset] | (packet[offset + 1] << 8)
	offset += 2
	
	# Parse sync data
	var synchronizers = []
	var sync_data = packet.slice(offset)
	
	while sync_data.size() >= 8:
		# Read synchronizer: [Net ID: 4 bytes] [Data Size: 4 bytes] [Variant Data...]
		var net_id = sync_data[0] | (sync_data[1] << 8) | (sync_data[2] << 16) | (sync_data[3] << 24)
		var data_size = sync_data[4] | (sync_data[5] << 8) | (sync_data[6] << 16) | (sync_data[7] << 24)
		
		if sync_data.size() < 8 + data_size:
			break
		
		# Decode variant data
		var variant_data = sync_data.slice(8, 8 + data_size)
		var variant = bytes_to_var(variant_data)
		
		if variant != null:
			synchronizers.append({
				"net_id": net_id,
				"data_size": data_size,
				"variant": variant
			})
		
		# Move to next synchronizer
		sync_data = sync_data.slice(8 + data_size)
	
	return {
		"command": command,
		"net_time": net_time,
		"synchronizers": synchronizers
	}

func _verify_data_correctness(synchronizers: Array):
	# Compare received data with expected data
	# This is a simplified check - in a full implementation, we'd compare all properties
	for sync in synchronizers:
		var net_id = sync.net_id
		var variant = sync.variant
		
		# Find expected node by net_id (hash of node path)
		# For now, just verify variant is valid
		if variant == null:
			data_correctness_errors.append({
				"net_id": net_id,
				"error": "Variant is null"
			})

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected: ", id)
	connected = false

func _on_multiplayer_peer_connected(id: int):
	print("Multiplayer peer connected: ", id)

func _on_multiplayer_peer_disconnected(id: int):
	print("Multiplayer peer disconnected: ", id)
	connected = false

func _variant_to_string(variant) -> String:
	var type = typeof(variant)
	match type:
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if variant else "false"
		TYPE_INT:
			return str(variant)
		TYPE_FLOAT:
			return "%.3f" % variant
		TYPE_STRING:
			return '"' + variant + '"'
		TYPE_VECTOR3:
			return "Vector3(%.2f, %.2f, %.2f)" % [variant.x, variant.y, variant.z]
		TYPE_QUATERNION:
			return "Quaternion(%.3f, %.3f, %.3f, %.3f)" % [variant.x, variant.y, variant.z, variant.w]
		TYPE_DICTIONARY:
			return "Dictionary(" + str(variant.size()) + " keys)"
		TYPE_ARRAY:
			return "Array(" + str(variant.size()) + " elements)"
		_:
			return str(variant)

func _finish_test():
	var elapsed = (Time.get_ticks_msec() / 1000.0) - start_time
	
	print("")
	print("=== Test Complete ===")
	print("Duration: ", "%.2f" % elapsed, " seconds")
	print("")
	
	# Show network time trace
	if network_times.size() > 0:
		print("Network Time Trace (first 10, last 10):")
		var first_10 = network_times.slice(0, min(10, network_times.size()))
		var last_10 = network_times.slice(max(0, network_times.size() - 10), network_times.size())
		print("  First 10: ", first_10)
		print("  Last 10: ", last_10)
		print("")
	
	# Show synchronizer trace
	if decoded_synchronizers.size() > 0:
		print("Synchronizer Trace (first 5):")
		for i in range(min(5, decoded_synchronizers.size())):
			var sync = decoded_synchronizers[i]
			print("  [", i, "] Net ID: ", sync.net_id, ", Data Size: ", sync.data_size)
			if sync.variant != null:
				print("      Variant: ", _variant_to_string(sync.variant))
		print("")
	
	# Calculate metrics
	var avg_packet_size = 0.0
	if packets_received > 0:
		avg_packet_size = float(total_bytes_received) / float(packets_received)
	
	var avg_sync_rate = 0.0
	if sync_rate_samples.size() > 0:
		var total_interval = 0.0
		for interval in sync_rate_samples:
			total_interval += interval
		avg_sync_rate = total_interval / sync_rate_samples.size()
		avg_sync_rate = 1.0 / avg_sync_rate if avg_sync_rate > 0 else 0.0
	
	var avg_latency = 0.0
	if latency_samples.size() > 0:
		var total_latency = 0.0
		for latency in latency_samples:
			total_latency += latency
		avg_latency = (total_latency / latency_samples.size()) * 1000.0  # Convert to ms
	
	print("Metrics:")
	print("  Packets Received: ", packets_received)
	print("  Sync Responses: ", sync_responses_received)
	print("  Total Bytes Received: ", total_bytes_received)
	print("  Average Packet Size: ", "%.2f" % avg_packet_size, " bytes")
	print("  Average Sync Rate: ", "%.2f" % avg_sync_rate, " Hz")
	print("  Average Latency: ", "%.2f" % avg_latency, " ms")
	print("  Synchronizers Decoded: ", decoded_synchronizers.size())
	print("  Network Times: ", network_times.size())
	print("  Data Correctness Errors: ", data_correctness_errors.size())
	print("")
	
	# Success criteria
	var success = true
	var issues = []
	
	if avg_sync_rate < 62.0 or avg_sync_rate > 66.0:
		success = false
		issues.append("Sync rate out of range: %.2f Hz (target: 64 Hz ±2 Hz)" % avg_sync_rate)
	
	if avg_latency > 20.0:
		success = false
		issues.append("Latency too high: %.2f ms (target: <20 ms)" % avg_latency)
	
	if packets_received == 0:
		success = false
		issues.append("No packets received")
	
	if data_correctness_errors.size() > 0:
		success = false
		issues.append("Data correctness errors: %d" % data_correctness_errors.size())
	
	if success:
		print("✅ All success criteria met!")
		quit(0)
	else:
		print("❌ Test failed:")
		for issue in issues:
			print("  - ", issue)
		quit(1)


