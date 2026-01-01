#!/bin/bash
# Run MultiplayerSynchronizer compatibility test in Godot

cd "$(dirname "$0")"

echo "Running MultiplayerSynchronizer compatibility test..."
echo ""

# Run the test scene
godot --headless --path . --script test_multisync_compatibility.gd 2>&1 | grep -v "^Godot Engine" | grep -v "^$" | head -200

echo ""
echo "Test complete."

