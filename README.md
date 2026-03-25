# Bushel

Bushel is a macOS SwiftUI app for managing Apple containers through the `container` CLI.

It provides a desktop UI for:

- Listing, starting, stopping, restarting, and deleting containers
- Opening logs, running one-off commands, and attaching an interactive shell
- Pulling, building, pruning, and inspecting images
- Creating and deleting volumes and networks
- Viewing container system status and disk usage

## Requirements

- macOS with Xcode installed
- Apple container CLI installed and available locally
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
- The default CLI path in the app is `/usr/local/bin/container`.
- The current Xcode project targets macOS `26.2`.

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
- Tests are mostly template stubs today and do not yet validate core behavior.

## Development Notes

- The CLI binary path is user-configurable in `Bushel/Views/SettingsView.swift`.
- Most container operations are routed through `Bushel/Services/ShellService.swift`.
- A bundled spec document is present at `mac_container_manager_spec.pdf`.
