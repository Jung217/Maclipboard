import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var selectedIndex: Int? = 0

    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Maclipboard")
                    .font(.headline)
                Spacer()
                Button(action: {
                    clipboardManager.clearUnpinnedHistory()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Clear Unpinned History")
                
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
                .help("Quit")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // List
            if clipboardManager.history.isEmpty {
                VStack {
                    Spacer()
                    Text("No history yet.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(clipboardManager.history.enumerated()), id: \.element.id) { index, item in
                                ClipboardItemRow(
                                    item: item,
                                    isSelected: selectedIndex == index,
                                    onSelect: {
                                        selectedIndex = index
                                    },
                                    onCommit: {
                                        clipboardManager.copyAndPaste(item: item)
                                    }
                                )
                                .environmentObject(clipboardManager)
                                .id(item.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        if let index = newIndex, index >= 0, index < clipboardManager.history.count {
                            DispatchQueue.main.async {
                                withAnimation {
                                    proxy.scrollTo(clipboardManager.history[index].id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(width: AppConstants.UI.panelWidth, height: AppConstants.UI.panelHeight)
        .background(Color(NSColor.windowBackgroundColor))
        .background(
            Group {
                Button("") { moveSelection(1) }
                    .keyboardShortcut(.downArrow, modifiers: [])
                Button("") { moveSelection(-1) }
                    .keyboardShortcut(.upArrow, modifiers: [])
                Button("") { handleReturn() }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        )
        .onAppear {
            selectedIndex = clipboardManager.history.isEmpty ? nil : 0
        }
    }
    
    private func moveSelection(_ delta: Int) {
        guard !clipboardManager.history.isEmpty else { return }
        
        var newIndex = (selectedIndex ?? 0) + delta
        if newIndex < 0 {
            newIndex = 0
        } else if newIndex >= clipboardManager.history.count {
            newIndex = clipboardManager.history.count - 1
        }
        
        selectedIndex = newIndex
    }
    
    private func handleReturn() {
        guard let idx = selectedIndex, idx < clipboardManager.history.count else { return }
        clipboardManager.copyAndPaste(item: clipboardManager.history[idx])
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onCommit: () -> Void
    
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var isHovered = false
    @State private var isClicked = false
    
    var body: some View {
        HStack {
            Text(item.content)
                .lineLimit(2)
                .truncationMode(.tail)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.vertical, 14)
                .padding(.leading, 16)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    clipboardManager.togglePin(for: item.id)
                }
            }) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .rotationEffect(item.isPinned ? .degrees(45) : .degrees(0))
                    .foregroundColor(item.isPinned ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
            .opacity(isHovered || item.isPinned ? 1 : 0)
        }
        .contentShape(Rectangle()) // So the entire HStack is clickable
        .help(item.content) // Full text tooltip on hover
        .background(
            isClicked ? Color.gray.opacity(0.3) :
            (isSelected || isHovered ? Color.gray.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
        // Adding a clear thin border to make cards "pop" per user request
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .scaleEffect(isClicked ? 0.96 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isClicked)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            isClicked = true
            onSelect()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isClicked = false
                onCommit()
            }
        }
    }
}
