import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var settings: SettingsManager
    @State private var selectedIndex: Int? = 0
    @State private var showSettings: Bool = false
    @State private var selectedTab: Int = 0 // 0: All, 1: Pinned
    
    @State private var showPreview: Bool = false
    
    private var displayedHistory: [ClipboardItem] {
        if selectedTab == 1 {
            return clipboardManager.history.filter { $0.isPinned }
        }
        return clipboardManager.history
    }
    
    var body: some View {
        ZStack {
            backgroundLayer
            
            VStack(spacing: 0) {
                headerView
                
                Divider()
                
                contentArea
            }
        }
        .frame(width: AppConstants.UI.panelWidth, height: AppConstants.UI.panelHeight)
        .preferredColorScheme(settings.colorScheme)
        .background(keyboardShortcutsLayer)
        .onAppear {
            selectedIndex = displayedHistory.isEmpty ? nil : 0
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var backgroundLayer: some View {
        if let nsImage = settings.backgroundImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: AppConstants.UI.panelWidth, height: AppConstants.UI.panelHeight)
                .blur(radius: settings.blurBackground ? settings.blurRadius : 0)
                .opacity(settings.panelOpacity)
                .clipped()
        } else {
            settings.panelColor
                .opacity(settings.panelOpacity)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Maclipboard")
                .font(.headline)
            Spacer()
            
            Button(action: { clipboardManager.clearUnpinnedHistory() }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("Clear Unpinned History")
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            }) {
                Image(systemName: "gearshape")
                    .foregroundColor(showSettings ? .blue : .primary.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .help("Settings")
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .help("Quit")
        }
        .padding()
    }
    
    @ViewBuilder
    private var contentArea: some View {
        if showSettings {
            SettingsView()
                .transition(.opacity)
        } else {
            ZStack {
                VStack(spacing: 0) {
                    mainListView
                    Divider()
                    tabPickerView
                }
                
                if showPreview {
                    previewOverlay
                }
            }
        }
    }
    
    @ViewBuilder
    private var previewOverlay: some View {
        if let idx = selectedIndex, idx < displayedHistory.count {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showPreview = false
                        }
                    }
                
                // Content Card
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.15)) {
                                showPreview = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .padding([.top, .trailing], 12)
                    }
                    
                    ScrollView {
                        Text(displayedHistory[idx].content)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: AppConstants.UI.panelWidth * 0.9, height: AppConstants.UI.panelHeight * 0.7)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(settings.panelColor)
                        .shadow(radius: 10)
                )
            }
            .transition(.opacity)
            .zIndex(1) // Ensure it draws above the list
        }
    }
    
    @ViewBuilder
    private var mainListView: some View {
        if displayedHistory.isEmpty {
            VStack {
                Spacer()
                Text(selectedTab == 1 ? "No pinned items." : "No history yet.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(displayedHistory.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemRow(
                                item: item,
                                isSelected: selectedIndex == index,
                                onSelect: { selectedIndex = index },
                                onCommit: { clipboardManager.copyAndPaste(item: item) }
                            )
                            .environmentObject(clipboardManager)
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: selectedIndex) { newIndex in
                    if let index = newIndex, index >= 0, index < displayedHistory.count {
                        DispatchQueue.main.async {
                            withAnimation {
                                proxy.scrollTo(displayedHistory[index].id, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var tabPickerView: some View {
        Picker("", selection: $selectedTab) {
            Text("All").tag(0)
            Text("Pinned").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var keyboardShortcutsLayer: some View {
        Group {
            Button("") { moveSelection(1) }
                .keyboardShortcut(.downArrow, modifiers: [])
            Button("") { moveSelection(-1) }
                .keyboardShortcut(.upArrow, modifiers: [])
            Button("") { handleReturn() }
                .keyboardShortcut(.return, modifiers: [])
            Button("") { switchTab(-1) }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Button("") { switchTab(1) }
                .keyboardShortcut(.rightArrow, modifiers: [])
                
            // New Hotkeys
            Button("") { handlePreview() }
                .keyboardShortcut(.space, modifiers: [])
            Button("") { handlePin() }
                .keyboardShortcut("p", modifiers: [.control])
            Button("") { handleDelete() }
                .keyboardShortcut(.delete, modifiers: [.command])
            Button("") { handleEscape() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
    
    private func moveSelection(_ delta: Int) {
        guard !displayedHistory.isEmpty else { return }
        
        var newIndex = (selectedIndex ?? 0) + delta
        if newIndex < 0 {
            newIndex = 0
        } else if newIndex >= displayedHistory.count {
            newIndex = displayedHistory.count - 1
        }
        
        selectedIndex = newIndex
    }
    
    private func handleReturn() {
        guard let idx = selectedIndex, idx < displayedHistory.count else { return }
        clipboardManager.copyAndPaste(item: displayedHistory[idx])
    }
    
    private func switchTab(_ direction: Int) {
        guard !showSettings else { return }
        let newTab = max(0, min(1, selectedTab + direction))
        if newTab != selectedTab {
            withAnimation {
                selectedTab = newTab
            }
        }
    }
    
    private func handlePreview() {
        guard !displayedHistory.isEmpty else { return }
        withAnimation(.easeIn(duration: 0.15)) {
            showPreview.toggle()
        }
    }
    
    private func handlePin() {
        guard !showPreview, let idx = selectedIndex, idx < displayedHistory.count else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            clipboardManager.togglePin(for: displayedHistory[idx].id)
        }
    }
    
    private func handleDelete() {
        guard !showPreview, let idx = selectedIndex, idx < displayedHistory.count else { return }
        
        let targetId = displayedHistory[idx].id
        withAnimation(.easeOut(duration: 0.2)) {
            clipboardManager.deleteItem(id: targetId)
            
            // Adjust the selected index if we deleted the last item in the list
            if let newCount = Optional(displayedHistory.count), newCount > 0 {
                if idx >= newCount {
                    selectedIndex = newCount - 1
                }
            } else {
                selectedIndex = nil
            }
        }
    }
    
    private func handleEscape() {
        if showPreview {
            withAnimation(.easeOut(duration: 0.15)) {
                showPreview = false
            }
        } else if showSettings {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSettings = false
            }
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("HidePanel"), object: nil)
        }
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
            isClicked ? Color.primary.opacity(0.2) :
            (isSelected || isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
        )
        // Adding a clear thin border to make cards "pop" per user request
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
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
