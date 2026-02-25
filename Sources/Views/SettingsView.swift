import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    @State private var isRecordingHotkey = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                appearanceSection
                Divider()
                panelAppearanceSection
                Divider()
                screenshotSection
                Divider()
                behaviorSection
                Divider()
                hotkeysSection
                Divider()
                aboutSection
            }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        }
    }
    
    // MARK: - Subviews
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Appearance")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation { settings.appearanceMode = AppConstants.Settings.defaultAppearance }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset Appearance")
            }
            
            Picker("Theme", selection: $settings.appearanceMode) {
                Text("System").tag(0)
                Text("Light").tag(1)
                Text("Dark").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
    
    private var panelAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Panel Appearance")
                    .font(.headline)
                Spacer()
                Button(action: {
                    withAnimation { 
                        settings.clearBackgroundImage()
                        settings.panelOpacity = AppConstants.Settings.defaultOpacity
                        settings.panelColorHex = AppConstants.Settings.defaultColorHex
                    }
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset Panel Appearance")
            }
            
            backgroundImageRow
            
            if settings.backgroundImage != nil {
                Toggle("Blur Background", isOn: $settings.blurBackground)
                    .padding(.top, 4)
                
                if settings.blurBackground {
                    blurRadiusRow
                }
            }
            
            HStack {
                Text("Background Color")
                Spacer()
                ColorPicker("", selection: $settings.panelColor)
                    .labelsHidden()
            }
            
            HStack {
                Text("Opacity")
                Spacer()
                Slider(value: $settings.panelOpacity, in: 0.1...1.0)
                    .frame(width: 140)
                Text(String(format: "%.0f%%", settings.panelOpacity * 100))
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.bottom, 8)
    }
    
    private var backgroundImageRow: some View {
        HStack {
            Text("Background Image")
            Spacer()
            if let nsImage = settings.backgroundImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 25)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        Button(action: {
                            withAnimation { settings.clearBackgroundImage() }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                    )
            } else {
                Button("Select Image...") {
                    settings.selectBackgroundImage()
                }
            }
        }
    }
    
    private var blurRadiusRow: some View {
        HStack {
            Text("Blur Radius")
                .foregroundColor(.secondary)
            Spacer()
            Slider(value: $settings.blurRadius, in: 0...50)
                .frame(width: 100)
            Text(String(format: "%.0f", settings.blurRadius))
                .frame(width: 30, alignment: .trailing)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 16)
        .padding(.bottom, 4)
    }
    
    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Screenshot Folder")
                    .font(.headline)
                Spacer()
                if settings.screenshotDirBookmark != nil {
                    Button(action: {
                        withAnimation { settings.resetScreenshotDirectory() }
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Reset to Default (Desktop)")
                }
            }
            
            HStack {
                Text(settings.screenshotDirectoryURL.path)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(4)
                
                Spacer()
                
                Button("Select Folder...") {
                    settings.selectScreenshotDirectory()
                }
            }
        }
    }
    
    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Behavior")
                .font(.headline)
            
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            Toggle("Clear History on Quit", isOn: $settings.clearOnQuit)
        }
        .padding(.bottom, 8)
    }
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcuts")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                // Interactive Global Hotkey Recorder
                HStack {
                    Text("Toggle Panel (Global)")
                        .foregroundColor(.primary)
                    Spacer()
                    
                    Button(action: {
                        isRecordingHotkey = true
                    }) {
                        Text(isRecordingHotkey ? "Recording..." : settings.globalHotkey.stringRepresentation)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isRecordingHotkey ? Color.blue.opacity(0.2) : Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isRecordingHotkey ? Color.blue : Color.primary.opacity(0.15), lineWidth: 1)
                            )
                            .cornerRadius(6)
                            .foregroundColor(isRecordingHotkey ? .blue : .primary)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .background(
                        HotkeyRecorderView(hotkey: $settings.globalHotkey, isRecording: $isRecordingHotkey)
                            .frame(width: 0, height: 0)
                            .opacity(0)
                    )
                }
                
                Divider().opacity(0.5)
                
                hotkeyRow(action: "Navigate History", keys: ["UP (↑)", "DOWN (↓)"], separator: "/")
                hotkeyRow(action: "Auto-Paste Item", keys: ["RETURN (⏎)"])
                hotkeyRow(action: "Preview Full Text", keys: ["SPACE"])
                hotkeyRow(action: "Toggle Pin Status", keys: ["CONTROL (⌃)", "P"])
                hotkeyRow(action: "Switch Tabs", keys: ["LEFT (←)", "RIGHT (→)"], separator: "/")
                hotkeyRow(action: "Delete Item", keys: ["COMMAND (⌘)", "BACKSPACE (⌫)"])
                hotkeyRow(action: "Delete All Items", keys: ["COMMAND (⌘)", "SHIFT (⇧)", "BACKSPACE (⌫)"])
            }
            .font(.system(.caption, design: .rounded))
        }
    }
    
    private func hotkeyRow(action: String, keys: [String], separator: String = "+") -> some View {
        HStack {
            Text(action)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(Array(keys.enumerated()), id: \.offset) { index, key in
                    Text(key)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(4)
                        .foregroundColor(.primary)
                        .font(.system(.caption, design: .monospaced))
                    
                    if index < keys.count - 1 {
                        Text(separator)
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Link(destination: URL(string: "https://github.com/Jung217/Maclipboard")!) {
                    Text("Maclipboard")
                        .font(.subheadline).bold()
                        .foregroundColor(.primary)
                }
                
                Text("A minimalist, keyboard-driven clipboard manager for macOS.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    
                Text("Copyright (c) 2026 C.J.Chien")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
