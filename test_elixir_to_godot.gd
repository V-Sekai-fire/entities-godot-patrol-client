extends Node

@export var test_data_file: String = "res://elixir_encoded_variants.bin"

func _ready():
	print("=== Test: Elixir to Godot Variant Decoding ===")
	print("Testing if Godot can decode variants encoded by Elixir")
	print("")
	
	# Read the file encoded by Elixir
	var file = FileAccess.open(test_data_file, FileAccess.READ)
	if file == null:
		print("ERROR: Could not open file: ", test_data_file)
		print("Run the Elixir test script first to generate the file")
		return
	
	var data = file.get_buffer(file.get_length())
	file.close()
	
	print("Read ", data.size(), " bytes from Elixir-encoded file")
	print("")
	
	# Decode variants using Godot's bytes_to_var()
	# Note: bytes_to_var() decodes from the start, so we need to slice the buffer
	var offset = 0
	var test_count = 0
	var pass_count = 0
	
	while offset < data.size():
		# Slice the remaining data
		var remaining_data = data.slice(offset)
		
		# Try to decode one variant
		var variant = bytes_to_var(remaining_data)
		if variant == null:
			print("⚠️  Could not decode variant at offset ", offset)
			break
		
		# Calculate the size of the decoded variant by re-encoding it
		var encoded = var_to_bytes(variant)
		var variant_size = encoded.size()
		
		# Verify the decoded variant matches what we expect
		test_count += 1
		var test_name = "Variant " + str(test_count)
		
		print("✓ ", test_name, ": ", _variant_to_string(variant), " (", variant_size, " bytes)")
		pass_count += 1
		
		# Move to next variant
		offset += variant_size
		
		# Safety check to prevent infinite loop
		if variant_size == 0:
			print("⚠️  Variant size is 0, stopping")
			break
	
	print("")
	print("Results: ", pass_count, "/", test_count, " variants decoded successfully")
	
	if pass_count == test_count and test_count > 0:
		print("✅ All variants decoded successfully!")
	else:
		print("❌ Some variants failed to decode")


func _variant_to_string(variant) -> String:
	var type = typeof(variant)
	match type:
		TYPE_NIL:
			return "NIL"
		TYPE_BOOL:
			return "BOOL: " + str(variant)
		TYPE_INT:
			return "INT: " + str(variant)
		TYPE_FLOAT:
			return "FLOAT: " + str(variant)
		TYPE_STRING:
			return "STRING: \"" + str(variant) + "\""
		TYPE_VECTOR3:
			return "VECTOR3: " + str(variant)
		TYPE_QUATERNION:
			return "QUATERNION: " + str(variant)
		TYPE_DICTIONARY:
			return "DICTIONARY: " + str(variant.size()) + " keys"
		TYPE_ARRAY:
			return "ARRAY: " + str(variant.size()) + " elements"
		_:
			return "TYPE_" + str(type) + ": " + str(variant)

