import SwiftUI

@main
struct MaclipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // We don't use a standard WindowGroup since it's a menu bar extra app
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class BorderlessFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var floatingPanel: NSPanel!
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    
    var clipboardManager = ClipboardManager()
    var settingsManager = SettingsManager()
    
    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissions()
        setupNotificationObservers()
        
        setupFloatingPanel()
        setupStatusItem()
        setupHotkeys()
        setupEventMonitors()
        
        checkForDMGLaunch()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if settingsManager.clearOnQuit {
            clipboardManager.clearAllHistory()
        }
    }
    
    // MARK: - Setup
    
    private func checkForDMGLaunch() {
        let bundlePath = Bundle.main.bundlePath
        // A simple heuristic: if running from /Volumes/ and it's on a read-only filesystem (typical for DMGs)
        if bundlePath.hasPrefix("/Volumes/") {
            // Give the app a moment to finish launching before showing the alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let alert = NSAlert()
                alert.messageText = "Running from Installer"
                alert.informativeText = "It looks like you opened Maclipboard directly from the installer disk image.\n\nPlease drag the Maclipboard app icon into the Applications folder shortcut provided in the installer window, then eject the installer and run the app from your Applications folder."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Quit")
                alert.addButton(withTitle: "Continue Anyway")
                
                NSApp.activate(ignoringOtherApps: true)
                let response = alert.runModal()
                
                if response == .alertFirstButtonReturn {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HidePanel"), object: nil, queue: .main) { [weak self] _ in
            self?.floatingPanel.orderOut(nil)
            NotificationCenter.default.post(name: NSNotification.Name("PanelDidHide"), object: nil)
        }
    }

    private func setupFloatingPanel() {
        let rect = NSRect(x: 0, y: 0, width: AppConstants.UI.panelWidth, height: AppConstants.UI.panelHeight)
        floatingPanel = BorderlessFloatingPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        floatingPanel.hasShadow = true
        floatingPanel.isFloatingPanel = true
        floatingPanel.level = .floating
        floatingPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        floatingPanel.titleVisibility = .hidden
        floatingPanel.titlebarAppearsTransparent = true
        floatingPanel.isMovableByWindowBackground = true
        floatingPanel.isOpaque = false
        floatingPanel.backgroundColor = .clear
        
        let hostingView = NSHostingView(
            rootView: ContentView()
                .environmentObject(clipboardManager)
                .environmentObject(settingsManager)
        )
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = AppConstants.UI.cornerRadius
        hostingView.layer?.masksToBounds = true
        floatingPanel.contentView = hostingView
        
        floatingPanel.standardWindowButton(.closeButton)?.isHidden = true
        floatingPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        floatingPanel.standardWindowButton(.zoomButton)?.isHidden = true
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        
        button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Maclipboard")
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func setupHotkeys() {
        HotkeyManager.shared.action = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleFloatingPanel()
            }
        }
        HotkeyManager.shared.registerCtrlV()
    }

    private func setupEventMonitors() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
        }
        
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
            return event
        }
    }

    // MARK: - Actions

    @objc private func togglePopover(_ sender: AnyObject?) {
        if floatingPanel.isVisible {
            floatingPanel.orderOut(nil)
            NotificationCenter.default.post(name: NSNotification.Name("PanelDidHide"), object: nil)
        } else {
            guard let button = statusItem.button else { return }
            storePreviousApp()
            
            let buttonFrame = button.window?.convertToScreen(button.frame) ?? NSRect.zero
            let width = AppConstants.UI.panelWidth
            let height = AppConstants.UI.panelHeight
            
            var x = buttonFrame.midX - (width / 2)
            let y = buttonFrame.minY - height - 5
            
            let screen = NSScreen.screens.first(where: { NSPointInRect(buttonFrame.origin, $0.frame) }) ?? NSScreen.main ?? NSScreen.screens[0]
            x = max(screen.visibleFrame.minX, min(x, screen.visibleFrame.maxX - width))
            
            floatingPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
            floatingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func toggleFloatingPanel() {
        if floatingPanel.isVisible && floatingPanel.isKeyWindow {
            floatingPanel.orderOut(nil)
            NotificationCenter.default.post(name: NSNotification.Name("PanelDidHide"), object: nil)
        } else {
            capturePreviousAppFromHotkey()
            positionAndShowFloatingPanel()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Helpers

    private func handleOutsideClick(_ event: NSEvent) {
        guard floatingPanel.isVisible,
              let frame = floatingPanel?.frame else { return }
              
        // Prevent dismissal if a modal window (like NSOpenPanel) is currently active
        if NSApp.modalWindow != nil {
            return
        }
        
        // Prevent dismissal if the user is clicking inside the macOS native Color Picker
        if NSColorPanel.shared.isVisible {
            let colorPanelFrame = NSColorPanel.shared.frame
            if NSMouseInRect(NSEvent.mouseLocation, colorPanelFrame, false) {
                return
            }
        }
              
        if !NSMouseInRect(NSEvent.mouseLocation, frame, false) {
            floatingPanel.orderOut(nil)
            NotificationCenter.default.post(name: NSNotification.Name("PanelDidHide"), object: nil)
        }
    }

    private func storePreviousApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            clipboardManager.previousApp = frontApp
        }
    }
    
    private func capturePreviousAppFromHotkey() {
        if let captured = HotkeyManager.shared.capturedApp,
           captured.bundleIdentifier != Bundle.main.bundleIdentifier {
            clipboardManager.previousApp = captured
        }
    }

    private func positionAndShowFloatingPanel() {
        let mouseLoc = NSEvent.mouseLocation
        let width = AppConstants.UI.panelWidth
        let height = AppConstants.UI.panelHeight

        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            ?? NSScreen.main ?? NSScreen.screens[0]
            
        let frame = screen.visibleFrame

        var x = mouseLoc.x - (width / 2)
        var y = mouseLoc.y + 10

        if (y + height) > frame.maxY {
            y = mouseLoc.y - height - 10
        }

        x = max(frame.minX, min(x, frame.maxX - width))
        y = max(frame.minY, y)

        floatingPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        floatingPanel.makeKeyAndOrderFront(nil)
    }
}
