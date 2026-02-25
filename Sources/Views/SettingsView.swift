import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                appearanceSection
                Divider()
                panelAppearanceSection
                resetButton
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
            Text("Appearance")
                .font(.headline)
            
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
            Text("Panel Appearance")
                .font(.headline)
            
            backgroundImageRow
            
            if settings.backgroundImage != nil {
                Toggle("Blur Background", isOn: $settings.blurBackground)
                    .padding(.top, 4)
                
                if settings.blurBackground {
                    blurRadiusRow
                }
            }
            
            ColorPicker("Background Color", selection: $settings.panelColor)
            
            HStack {
                Text("Opacity")
                Spacer()
                Slider(value: $settings.panelOpacity, in: 0.1...1.0)
                    .frame(width: 100)
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
    
    private var resetButton: some View {
        Button("Reset to Default") {
            withAnimation {
                settings.clearBackgroundImage()
                settings.panelOpacity = AppConstants.Settings.defaultOpacity
                settings.panelColorHex = AppConstants.Settings.defaultColorHex
                settings.appearanceMode = AppConstants.Settings.defaultAppearance
            }
        }
    }
    
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.bottom, 4)
            
            Group {
                hotkeyRow(key: "⌃ V", action: "Toggle Panel")
                hotkeyRow(key: "↑ ↓", action: "Navigate History")
                hotkeyRow(key: "⏎", action: "Auto-Paste Item")
                hotkeyRow(key: "← →", action: "Switch Tabs")
                hotkeyRow(key: "Space", action: "Preview Full Text")
                hotkeyRow(key: "⌃ P", action: "Toggle Pin Status")
                hotkeyRow(key: "⌘ ⌫", action: "Delete Item")
            }
            .font(.system(.caption, design: .rounded))
        }
    }
    
    private func hotkeyRow(key: String, action: String) -> some View {
        HStack {
            Text(key)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.1))
                .cornerRadius(4)
                .foregroundColor(.primary)
                .bold()
            
            Text(action)
                .foregroundColor(.secondary)
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
