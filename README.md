# Bushel

Bushel is a macOS SwiftUI app for managing Apple containers through the `container` CLI.

It provides a desktop UI for:

- Listing, starting, stopping, restarting, and deleting containers
- Opening logs, running one-off commands, and attaching an interactive shell
- Pulling, building, pruning, and inspecting images
- Creating and deleting volumes and networks
- Viewing container system status and disk usage

## Requirements

- Apple Silicon Mac running macOS 26.0 or later (Intel is unsupported)
- Xcode 26 or later
- Apple container CLI 1.x installed and available locally
- A machine that can run the checked-in deployment target in the Xcode project

Install the CLI with:

```bash
brew install container
```

## Getting Started

1. Open `Bushel.xcodeproj` in Xcode.
2. Update the app signing configuration for your machine.
3. Build and run the `Bushel` scheme.
4. If needed, open Settings in the app and point Bushel at your `container` binary.

Notes:

- The project does not assume a specific local signing setup. Configure signing for your own machine in Xcode before building for the first time.
- The CLI is discovered from PATH, `/opt/homebrew/bin`, and `/usr/local/bin`. An explicit Settings path overrides discovery.
- The current Xcode project targets macOS `26.0`.

## Project Layout

- `Bushel/BushelApp.swift`: app entry point and shared environment state
- `Bushel/ContentView.swift`: sidebar and top-level section routing
- `Bushel/Models`: decoded container CLI response models
- `Bushel/Services`: shell execution, container/image/network/volume/system services, and terminal session support
- `Bushel/ViewModels`: observable app state and async actions
- `Bushel/Views`: SwiftUI screens for each resource area
- `BushelTests` and `BushelUITests`: test targets

## How Bushel Works

Bushel shells out to the Apple `container` binary rather than embedding a custom backend. JSON-formatted CLI output is decoded into Swift models and displayed in SwiftUI views. Long-running operations such as logs, image pulls, image builds, and terminal sessions are streamed through the service layer.

## Current State

- The app structure is cleanly split by model, service, view model, and view.
- Interactive container management is implemented across all major resource types.
- Unit tests cover CLI discovery/version policy and legacy/current resource JSON decoding.

## Development Notes

- The CLI binary path is user-configurable in `Bushel/Views/SettingsView.swift`.
- Most container operations are routed through `Bushel/Services/ShellService.swift`.
- `mac_container_manager_spec.pdf` is the original March 2026 specification; CLI 1.x behavior supersedes it.

## CLI 1.x compatibility

The CLI path is checked on first command and 0.x/2.x versions produce a clear error. The 1.6.1 source shapes are covered by fixtures for status, images, volumes, and networks. Container list/inspect accepts both legacy string status and current nested runtime status. Missing optional volume size is displayed as Unknown. System status uses JSON where supported, with a legacy text fallback. Invalid CLI paths/unsupported versions are surfaced instead of an empty stopped-state screen.

Verification used the upstream 1.6.1 source and extracted command help without replacing or starting the installed daemon. Live start/stop/exec/build with a 1.6.1 daemon still requires a dedicated test environment. The bundle identifier is `com.kazobe.Bushel`; Developer ID signing/notarization is required before distributing a DMG.

For release preparation, build the app and run `scripts/sign-notarize.sh /path/to/Bushel.app` with `DEVELOPER_ID_APPLICATION` and an existing `NOTARYTOOL_PROFILE`. The script verifies signatures, submits the DMG, waits for notarization, staples the ticket, and assesses the finished image. No signing identity or credentials are stored in the repository.

A repeatable command-surface audit is available in `scripts/audit-cli-help.py`.
Pass `--binary /path/to/extracted/container`, `--build-plugin /path/to/extracted/build`,
and `--output /tmp/container-help-audit.json`. It checks all 26 command surfaces
and their used flags without starting a daemon or executing container operations.
The extracted official 1.6.1 tools passed this audit. This does not replace a live
VM/container lifecycle rehearsal on a dedicated 1.6.1 host.
