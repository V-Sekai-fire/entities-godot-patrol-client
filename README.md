# Godot MultiplayerSynchronizer Test Client

Test client for verifying MultiplayerSynchronizer compatibility with the Spatial Node Store backend.

## Overview

This Godot project tests the binary packet format compatibility between:
- **Backend**: Spatial Node Store server (Elixir/Erlang)
- **Client**: Godot Engine with MultiplayerSynchronizer

## Features

- Connects to Spatial Node Store server via ENet DTLS
- Sends MultiplayerSynchronizer sync requests
- Receives and decodes binary sync packets
- Displays connection status and packet information

## Usage

1. Start the Spatial Node Store server:
   ```bash
   cd /path/to/bug-free-octo-parakeet
   mix run --no-halt
   ```

2. Open this project in Godot 4.3+

3. Run the project (F5)

4. Click "Connect" to connect to the server (default: 127.0.0.1:7777)

5. The client will automatically request sync packets at 64 Hz

6. View packet information in the log text area

## Packet Format

The client expects MultiplayerSynchronizer binary packets:

**Full Sync Packet**:
```
[Command: 1 byte] [Network Time: 2 bytes] [Sync Data...]
```

**Sync Data per Synchronizer**:
```
[Net ID: 4 bytes] [Data Size: 4 bytes] [Encoded Variants...]
```

## Implementation Notes

- Uses ENet DTLS for connection (channel 0 for multiplayer sync)
- Erlang term encoding for variant data (compatible with Godot)
- Network time is 16-bit (wraps at 65535)
- Currently uses simplified encoding/decoding (production would use proper Erlang term format)

## Future Enhancements

- Proper Erlang term encoding/decoding
- Delta sync support
- Visibility filtering
- Property change detection
- Full MultiplayerSynchronizer integration

