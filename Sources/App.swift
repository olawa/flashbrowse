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
    private var scrollMonitor: Any?
    private var keyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        
        // Remote Scroll Monitor: Hold Command and scroll trackpad to scroll external screen!
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if event.modifierFlags.contains(.command) && SharedInspectorState.shared.isInspectorWindowOpen {
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
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
