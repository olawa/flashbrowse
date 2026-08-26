import SwiftUI
import AppKit

@main
struct FlashbrowseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            
            CommandMenu("Workspaces") {
                Button("Command Palette...") {
                    // Handled in view
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Divider()
                
                Button("Switch to Workspace 1") {
                    NotificationCenter.default.post(name: .flashbrowseSwitchWorkspace, object: 1)
                }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Switch to Workspace 2") {
                    NotificationCenter.default.post(name: .flashbrowseSwitchWorkspace, object: 2)
                }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Switch to Workspace 3") {
                    NotificationCenter.default.post(name: .flashbrowseSwitchWorkspace, object: 3)
                }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Switch to Workspace 4") {
                    NotificationCenter.default.post(name: .flashbrowseSwitchWorkspace, object: 4)
                }
                    .keyboardShortcut("4", modifiers: .command)
                
                Divider()
                
                Button("Save Layout to Workspace 1") {
                    NotificationCenter.default.post(name: .flashbrowseSaveWorkspace, object: 1)
                }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Save Layout to Workspace 2") {
                    NotificationCenter.default.post(name: .flashbrowseSaveWorkspace, object: 2)
                }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("Save Layout to Workspace 3") {
                    NotificationCenter.default.post(name: .flashbrowseSaveWorkspace, object: 3)
                }
                    .keyboardShortcut("3", modifiers: [.command, .option])
                Button("Save Layout to Workspace 4") {
                    NotificationCenter.default.post(name: .flashbrowseSaveWorkspace, object: 4)
                }
                    .keyboardShortcut("4", modifiers: [.command, .option])
            }
            
            CommandMenu("View") {
                Button("Toggle Integrated Terminal") {
                    TerminalService.shared.toggleTerminal()
                }
                .keyboardShortcut("j", modifiers: .command)
                
                Button("Open Multi-Monitor Inspector") {
                    InspectorWindowController.shared.toggleWindow()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                
                Button("Jump Mouse to External Screen") {
                    InspectorWindowController.shared.toggleMouseBetweenScreens()
                }
                .keyboardShortcut("<", modifiers: .command)
                
                Divider()
                
                Button("Scroll Inspector Down") {
                    SharedInspectorState.shared.scrollInspector(by: 160)
                }
                .keyboardShortcut(.downArrow, modifiers: .option)
                
                Button("Scroll Inspector Up") {
                    SharedInspectorState.shared.scrollInspector(by: -160)
                }
                .keyboardShortcut(.upArrow, modifiers: .option)
                
                Divider()
                
                Button("Toggle Hidden Files") {
                    // Handled in view
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            }
            
            CommandMenu("Tools") {
                Button("Batch Rename...") {
                    // Handled in view
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                
                Button("Paste Clipboard as File") {
                    // Handled in view
                }
                .keyboardShortcut("v", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    public static var lastWindowActivationTime: Date = Date()
    
    private var scrollMonitor: Any?
    private var keyMonitor: Any?
    private var globalMouseMonitor: Any?
    private var hoverCheckTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        Self.lastWindowActivationTime = Date()
        
        setupHoverActivation()
        
        // Listen to window focus events to record activation time
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            Self.lastWindowActivationTime = Date()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Self.lastWindowActivationTime = Date()
        }
        
        // Touch / Trackpad & Remote Scroll Monitor
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe, .leftMouseDown, .magnify]) { event in
            // Check if interaction is targeted at Inspector Window
            if let inspWin = InspectorWindowController.shared.window, inspWin.isVisible {
                let mouseLoc = NSEvent.mouseLocation
                let isOverInspector = inspWin.frame.contains(mouseLoc) || event.window == inspWin
                
                if isOverInspector {
                    // Auto-activate inspector window so touch / gestures work without prior click
                    if NSApp.keyWindow != inspWin && (event.type == .leftMouseDown || event.type == .magnify || event.type == .scrollWheel) {
                        inspWin.makeKey()
                    }
                    
                    // Trackpad / iPad swipe when inspecting images
                    if SharedInspectorState.shared.contentType == .image {
                        if event.type == .swipe {
                            let dx = event.deltaX
                            if dx != 0 {
                                Task { @MainActor in
                                    SharedInspectorState.shared.handleHorizontalScroll(deltaX: dx * 50)
                                }
                                return nil
                            }
                        } else if event.type == .scrollWheel && !event.modifierFlags.contains(.command) {
                            let dx = event.scrollingDeltaX
                            let dy = event.scrollingDeltaY
                            // Prioritize horizontal swipe over slight vertical movement
                            if abs(dx) > 8 && abs(dx) > abs(dy) * 1.2 {
                                Task { @MainActor in
                                    SharedInspectorState.shared.handleHorizontalScroll(deltaX: dx)
                                }
                                return nil
                            }
                        }
                    }
                }
            }
            
            // Remote Scroll Monitor: Hold Command and scroll trackpad to scroll inspector vertically
            if event.type == .scrollWheel && event.modifierFlags.contains(.command) && SharedInspectorState.shared.isInspectorWindowOpen {
                let dy = event.scrollingDeltaY
                if dy != 0 {
                    Task { @MainActor in
                        SharedInspectorState.shared.scrollInspector(by: -dy * 10)
                    }
                    return nil // Intercept event so file list doesn't scroll
                }
            }
            return event
        }
        
        // Key Monitor for Swedish layout '<' (keyCode 50) with Command
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && (event.keyCode == 50 || event.characters == "<" || event.characters == ">") {
                Task { @MainActor in
                    InspectorWindowController.shared.toggleMouseBetweenScreens()
                }
                return nil
            }
            return event
        }
    }
    
    // MARK: - Focus Follows Mouse (Hover to Activate Window)
    private func setupHoverActivation() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMouseHoverActivation()
            }
        }
        
        hoverCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkMouseHoverActivation()
            }
        }
    }
    
    @MainActor
    private func checkMouseHoverActivation() {
        guard UserDefaults.standard.bool(forKey: "flashbrowse_hover_activate") else { return }
        guard !NSApp.isActive else { return }
        
        let mouseLoc = NSEvent.mouseLocation
        if let mainWin = NSApp.windows.first(where: { $0.isVisible && $0 != InspectorWindowController.shared.window && !($0 is NSPanel) }) {
            if mainWin.frame.contains(mouseLoc) {
                NSApp.activate(ignoringOtherApps: true)
                mainWin.makeKey()
                Self.lastWindowActivationTime = Date()
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
