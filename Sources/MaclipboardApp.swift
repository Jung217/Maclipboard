import SwiftUI

@main
struct MaclipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // We don't use a standard WindowGroup since it's a menu bar extra app
    var body: some Scene {
        Settings {
            Text("Settings")
        }
    }
}

class BorderlessFloatingPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var floatingPanel: NSPanel!
    var clipboardManager = ClipboardManager()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permissions at startup for auto-pasting
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HidePanel"), object: nil, queue: .main) { [weak self] _ in
            self?.floatingPanel.orderOut(nil)
            self?.popover.performClose(nil)
            // Removed NSApplication.shared.hide(nil) — it interferes with explicit app activation
        }
        
        // Create the SwiftUI view for the popover/panel
        let contentView = ContentView()
            .environmentObject(clipboardManager)
        
        // Create the popover (for menu bar click)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 350, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        // Create the floating panel (for global hotkey)
        floatingPanel = BorderlessFloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 450),
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
        
        let hostingView = NSHostingView(rootView: contentView)
        // Ensure rounding fits standard macOS style
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.masksToBounds = true
        floatingPanel.contentView = hostingView
        
        // Hide standard window buttons
        floatingPanel.standardWindowButton(.closeButton)?.isHidden = true
        floatingPanel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        floatingPanel.standardWindowButton(.zoomButton)?.isHidden = true

        // Create the status item (menu bar icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Maclipboard")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        // Setup Hotkey
        HotkeyManager.shared.action = { [weak self] in
            DispatchQueue.main.async {
                self?.toggleFloatingPanel()
            }
        }
        HotkeyManager.shared.registerCtrlV()
        
        setupEventMonitors()
    }
    
    func storePreviousApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            clipboardManager.previousApp = frontApp
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if floatingPanel.isVisible { floatingPanel.orderOut(nil) }
        
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                storePreviousApp()
                
                // Show popover first
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                
                // Do not activate NSApp here. Activating it forces a space switch 
                // if the OS thinks the "primary" space for the app is elsewhere.
                // The popover itself will receive keystrokes without full app activation.
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    var eventMonitor: Any?
    var localEventMonitor: Any?
    
    func setupEventMonitors() {
        // Global monitor catches clicks in other apps
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
        }
        
        // Local monitor catches clicks outside the panel but still within our app's menu bar/status item
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleOutsideClick(event)
            return event
        }
    }
    
    func handleOutsideClick(_ event: NSEvent) {
        guard floatingPanel.isVisible else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        if !NSMouseInRect(mouseLocation, floatingPanel.frame, false) {
            floatingPanel.orderOut(nil)
        }
    }
    
    func toggleFloatingPanel() {
        if popover.isShown { popover.performClose(nil) }
        
        if floatingPanel.isVisible && floatingPanel.isKeyWindow {
            floatingPanel.orderOut(nil)
        } else {
            // Use the app captured synchronously in the Carbon callback — this is the real
            // previously-focused app, captured before our process stole focus
            if let captured = HotkeyManager.shared.capturedApp,
               captured.bundleIdentifier != Bundle.main.bundleIdentifier {
                clipboardManager.previousApp = captured
            }

            let mouseLocation = NSEvent.mouseLocation
            let width: CGFloat = 350
            let height: CGFloat = 450

            let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
                ?? NSScreen.main
                ?? NSScreen.screens[0]
            let screenFrame = screen.visibleFrame

            var x = mouseLocation.x - (width / 2)
            var y = mouseLocation.y + 10

            if y + height > screenFrame.maxY {
                y = mouseLocation.y - height - 10
            }

            x = max(screenFrame.minX, min(x, screenFrame.maxX - width))
            y = max(screenFrame.minY, y)

            floatingPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
            floatingPanel.makeKeyAndOrderFront(nil)
        }
    }
}
