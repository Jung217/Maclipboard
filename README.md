# Maclipboard

Maclipboard is a lightweight, fast, and minimalistic clipboard manager for macOS. It runs in the background, keeping track of your clipboard history, and allows you to quickly access and auto-paste previously copied items using keyboard hotkeys.

## Features
- **Clipboard History**: Automatically records text copied to your clipboard.
- **Quick Access**: Bring up the clipboard history panel with a global hotkey.
- **Auto-Paste**: Select an item from the history and it automatically pastes into your active application.
- **Native & Lightweight**: Built purely with Swift and designed to consume minimal system resources with no heavy dependencies.

## Prerequisites
To build and run this application yourself, you will need:
- A macOS machine.
- [Xcode Command Line Tools](https://developer.apple.com/xcode/features/) installed, which includes the Swift compiler (`swiftc`). You can install them by running `xcode-select --install` in your terminal.

## How to Build and Run

Maclipboard includes a convenient `Makefile` to handle building and running the application natively without needing to open Xcode.

1. **Navigate to the Project directory**:
   Open your terminal and navigate to the folder containing the project files.

2. **Build the Application**:
   Simply run the following command in the project directory:
   ```bash
   make app
   ```
   This will compile the Swift source files and assemble the `Maclipboard.app` bundle in the `build/` directory.

3. **Run the Application**:
   To build and start the app immediately, run:
   ```bash
   make run
   ```
   This will launch the app. Make sure to grant it the necessary Accessibility permissions in **System Settings > Privacy & Security > Accessibility** if prompted, as it needs them to perform global hotkey listening and auto-pasting.

4. **Clean the Build Directory**:
   If you want to remove the compiled app and start fresh, run:
   ```bash
   make clean
   ```

## Customization
Since you have the source code, you can easily tweak the app yourself. You can customize the application's appearance by editing the SwiftUI code in `Sources/ContentView.swift`, or modify the copy-paste behaviors and shortcuts in `Sources/Core/ClipboardManager.swift` and `Sources/Core/HotkeyManager.swift`.
