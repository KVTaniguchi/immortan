# Immortan

Immortan is a macOS control app for a Gas Town workspace. It gives you a PM-friendly dashboard to run and monitor agent rigs without living in tmux.

## What It Does

- Shows town and rig status from `gt status --json`
- Lets you create rigs from new projects or Git repos
- Lets you import an existing project folder as a rig
- Provides in-app Mayor chat and quick directives
- Runs startup checks for Ollama, Goose, `gt`, and required models

## Project Layout

- `GastownController/`: SwiftUI macOS application
- `GastownControllerTests/`: unit tests for service logic
- `settings/`: Gas Town agent/model configuration
- `mayor/`, `daemon/`, `witness/`, `polecats/`: runtime workspace state

## Requirements

- macOS 14+
- Xcode (for building/running the app)
- Homebrew tools used by runtime checks:
  - `gt`
  - `goose`
  - `ollama`
- Ollama models used by default:
  - `qwen2.5-coder:32b` (Mayor)
  - `glm4:9b` (Polecat)

## Run

1. Open `GastownController.xcodeproj` in Xcode.
2. Run the `GastownController` target.
3. Complete setup checks in the app.
4. Open `Add Rig` and choose one mode:
   - `New Project`: create and adopt a new local project
   - `Import Folder`: register an existing folder as a rig
   - `Clone Git Repo`: add a rig from a remote repository URL

## Notes

- Imported/external projects do not need to live inside this repository.
- The controller only displays rigs currently registered in this Gas Town workspace.
- Runtime folders and logs in this repo are environment state, not app source.
