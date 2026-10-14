import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement

// `TileAll --layout N WxH` prints the grid for N windows without touching anything.
let args = CommandLine.arguments
if args.count == 4, args[1] == "--layout", let n = Int(args[2]) {
    let dims = args[3].split(separator: "x").compactMap { Double($0) }
    let rect = CGRect(x: 0, y: 0, width: dims[0], height: dims[1])
    print("rows:", Layout.rows(count: n, in: rect.size))
    for f in Layout.frames(count: n, in: rect, gap: 0) { print(" ", f) }
    exit(0)
}

/// Global hotkeys via Carbon — works without Accessibility permission and never
/// swallows keys from other apps except the exact combos registered.
enum HotKeys {
    nonisolated(unsafe) static var handlers: [UInt32: () -> Void] = [:]

    static func install() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            HotKeys.handlers[id.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }

    static func register(_ id: UInt32, key: Int, modifiers: Int, _ handler: @escaping () -> Void) {
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(key), UInt32(modifiers), EventHotKeyID(signature: OSType(0x54494C45), id: id),
                            GetApplicationEventTarget(), 0, &ref)
        handlers[id] = handler
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tiler = Tiler()
    private var statusItem: NSStatusItem!
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_: Notification) {
        tiler.gap = defaults.bool(forKey: "gaps") ? 8 : 0

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Tile All")
        rebuildMenu()

        let hyper = controlKey | optionKey | cmdKey
        HotKeys.install()
        HotKeys.register(1, key: kVK_ANSI_G, modifiers: hyper) { [weak self] in self?.tile() }
        HotKeys.register(2, key: kVK_ANSI_Z, modifiers: hyper) { [weak self] in self?.restore() }

        ensureTrusted(prompt: true)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let tile = NSMenuItem(title: "Tile All Windows", action: #selector(tile), keyEquivalent: "g")
        tile.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(tile)
        let restore = NSMenuItem(title: "Restore Previous Layout", action: #selector(restore), keyEquivalent: "z")
        restore.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(restore)
        menu.addItem(.separator())
        let gaps = NSMenuItem(title: "Gaps Between Windows", action: #selector(toggleGaps), keyEquivalent: "")
        gaps.state = tiler.gap > 0 ? .on : .off
        menu.addItem(gaps)
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Tile All", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
        for item in menu.items where item.action != #selector(NSApplication.terminate) { item.target = self }
        statusItem.menu = menu
    }

    @discardableResult
    private func ensureTrusted(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    @objc private func tile() {
        guard ensureTrusted(prompt: true) else { return }
        tiler.tileAll()
    }

    @objc private func restore() {
        guard ensureTrusted(prompt: true), tiler.canRestore else { NSSound.beep(); return }
        tiler.restore()
    }

    @objc private func toggleGaps() {
        tiler.gap = tiler.gap > 0 ? 0 : 8
        defaults.set(tiler.gap > 0, forKey: "gaps")
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("TileAll: launch-at-login change failed: \(error)")
        }
        rebuildMenu()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
