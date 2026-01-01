extends Node

@export var output_file: String = "res://godot_encoded_variants.bin"

func _ready():
	print("=== Test: Godot to Elixir Variant Encoding ===")
	print("Encoding variants in Godot for Elixir to decode")
	print("")
	
	# Create test variants
	var variants = [
		null,  # NIL
		true,  # BOOL
		false,  # BOOL
		42,  # INT
		-100,  # INT
		3.14,  # FLOAT
		-2.5,  # FLOAT
		"hello",  # STRING
		"world",  # STRING
		Vector3(1.0, 2.0, 3.0),  # VECTOR3
		Vector3(-1.0, 0.0, 1.0),  # VECTOR3
		Quaternion(0.0, 0.0, 0.0, 1.0),  # QUATERNION
		{"key1": "value1", "key2": 42},  # DICTIONARY
		{"nested": {"inner": "value"}},  # NESTED DICTIONARY
		[1, 2, 3],  # ARRAY
		["a", "b", "c"],  # ARRAY
		[1.0, 2.0, 3.0],  # ARRAY of floats
	]
	
	# Encode all variants
	var encoded_data = PackedByteArray()
	var variant_count = 0
	
	for variant in variants:
		var encoded = var_to_bytes(variant)
		encoded_data.append_array(encoded)
		variant_count += 1
		print("Encoded variant ", variant_count, ": ", _variant_to_string(variant))
	
	# Write to file
	var file = FileAccess.open(output_file, FileAccess.WRITE)
	if file == null:
		print("ERROR: Could not open file for writing: ", output_file)
		return
	
	file.store_buffer(encoded_data)
	file.close()
	
	print("")
	print("✅ Encoded ", variant_count, " variants to file: ", output_file)
	print("   Total size: ", encoded_data.size(), " bytes")
	print("")
	print("Now run the Elixir test script to decode these variants")

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

