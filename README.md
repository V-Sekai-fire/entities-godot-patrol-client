# entities-godot-patrol-client

A Godot test project that checks the scene synchronizer's packet format against an Elixir spatial node store.

## What it is for

It connects to the server over ENet, asks for sync packets and decodes them. Its scripts check
both directions: that variants and full and delta sync packets encoded in Elixir decode in the
engine, and that the engine's encoding decodes in Elixir. The server is
`interactor-bug-free-octo-parakeet-fire`.

## Run

Start the server from its repository with `mix run --no-halt`, then open this project in the
editor and run it. `run_test.sh` runs the compatibility check from a shell.

## Licence

This repository does not state a licence.
