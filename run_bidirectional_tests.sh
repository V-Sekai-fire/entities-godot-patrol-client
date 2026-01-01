#!/bin/bash

# Run bidirectional variant encoding tests
# Tests Elixir -> Godot and Godot -> Elixir compatibility

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Bidirectional Variant Encoding Tests ==="
echo ""
echo "Project root: $PROJECT_ROOT"
echo "Test directory: $SCRIPT_DIR"
echo ""

# Test 1: Elixir -> Godot
echo "Test 1: Elixir encodes variants for Godot to decode"
echo "---------------------------------------------------"
cd "$PROJECT_ROOT"
if [ -f "mix.exs" ]; then
  # Compile project first
  echo "Compiling project..."
  mix compile --force || {
    echo "ERROR: Failed to compile project"
    exit 1
  }
  
  # Run the Elixir encoding script using Mix
  mix run "$SCRIPT_DIR/test_elixir_to_godot.exs" || {
    echo "ERROR: Failed to run Elixir encoding test"
    exit 1
  }
else
  echo "ERROR: Not in project root (mix.exs not found)"
  exit 1
fi

echo ""
echo "✅ Elixir encoding complete"
echo "   File: $SCRIPT_DIR/elixir_encoded_variants.bin"
echo ""
echo "Next: Run test_elixir_to_godot.gd in Godot to decode"
echo ""

# Test 2: Godot -> Elixir
echo "Test 2: Godot encodes variants for Elixir to decode"
echo "---------------------------------------------------"
echo "First, run test_godot_to_elixir.gd in Godot to generate godot_encoded_variants.bin"
echo "Then run this script again, or manually run:"
echo "  elixir -pa \"_build/dev/lib/*/ebin\" \"$SCRIPT_DIR/test_godot_to_elixir.exs\""
echo ""

if [ -f "$SCRIPT_DIR/godot_encoded_variants.bin" ]; then
  echo "Found godot_encoded_variants.bin, running Elixir decoder..."
  cd "$PROJECT_ROOT"
  mix run "$SCRIPT_DIR/test_godot_to_elixir.exs" || {
    echo "ERROR: Failed to run Elixir decoding test"
    exit 1
  }
  echo ""
  echo "✅ Elixir decoding complete"
else
  echo "⚠️  godot_encoded_variants.bin not found"
  echo "   Run test_godot_to_elixir.gd in Godot first"
fi

echo ""
echo "=== All Tests Complete ==="

