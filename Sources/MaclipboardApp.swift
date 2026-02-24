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
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var floatingPanel: NSPanel!
    private var eventMonitor: Any?
    private var localEventMonitor: Any?
    
    var clipboardManager = ClipboardManager()
    
    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissions()
        setupNotificationObservers()
        
        setupPopover()
        setupFloatingPanel()
        setupStatusItem()
        setupHotkeys()
        setupEventMonitors()
    }
    
    // MARK: - Setup

    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HidePanel"), object: nil, queue: .main) { [weak self] _ in
            self?.floatingPanel.orderOut(nil)
            self?.popover.performClose(nil)
        }
    }

    private func setupPopover() {
        let contentView = ContentView().environmentObject(clipboardManager)
        popover = NSPopover()
        popover.contentSize = NSSize(width: AppConstants.UI.panelWidth, height: AppConstants.UI.panelHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
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
        
        let hostingView = NSHostingView(rootView: ContentView().environmentObject(clipboardManager))
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
        if floatingPanel.isVisible { floatingPanel.orderOut(nil) }
        
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            storePreviousApp()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func toggleFloatingPanel() {
        if popover.isShown { popover.performClose(nil) }
        
        if floatingPanel.isVisible && floatingPanel.isKeyWindow {
            floatingPanel.orderOut(nil)
        } else {
            capturePreviousAppFromHotkey()
            positionAndShowFloatingPanel()
        }
    }

    // MARK: - Helpers

    private func handleOutsideClick(_ event: NSEvent) {
        guard floatingPanel.isVisible,
              let frame = floatingPanel?.frame else { return }
              
        if !NSMouseInRect(NSEvent.mouseLocation, frame, false) {
            floatingPanel.orderOut(nil)
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
