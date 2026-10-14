import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

struct ManagedWindow {
    let element: AXUIElement
    let app: AXUIElement
    let frame: CGRect // AX coordinates: origin at top-left of the primary display
}

/// Finds the normal, visible windows on the current Space (all apps, or just one) and
/// tiles each display's windows into a grid that fills its usable area.
final class Tiler {
    var gap: CGFloat = 0
    private var snapshot: [(ManagedWindow, CGRect)] = []

    var canRestore: Bool { !snapshot.isEmpty }

    /// Tiles only `pid`'s windows, or every app's when `pid` is nil.
    func tile(pid: pid_t? = nil) {
        let windows = visibleWindows(pid: pid)
        guard !windows.isEmpty else { return }
        snapshot = windows.map { ($0, $0.frame) }

        let screens = NSScreen.screens.map { axRect($0.visibleFrame) }
        var byScreen: [Int: [ManagedWindow]] = [:]
        for w in windows {
            byScreen[screenIndex(for: w.frame, in: screens), default: []].append(w)
        }

        for (index, group) in byScreen {
            let area = screens[index]
            let rows = Layout.rows(count: group.count, in: area.size)
            let targets = Layout.frames(count: group.count, in: area, gap: gap)
            // Keep windows roughly where they already are: top-most go to the top row,
            // and within a row, left-most go left.
            var ordered: [ManagedWindow] = []
            var remaining = group.sorted { $0.frame.midY < $1.frame.midY }
            for cols in rows {
                ordered += remaining.prefix(cols).sorted { $0.frame.midX < $1.frame.midX }
                remaining.removeFirst(cols)
            }
            for (window, frame) in zip(ordered, targets) {
                setFrame(window, frame)
            }
        }
    }

    func restore() {
        for (window, frame) in snapshot { setFrame(window, frame) }
        snapshot = []
    }

    // MARK: - Window discovery

    func visibleWindows(pid only: pid_t? = nil) -> [ManagedWindow] {
        let me = ProcessInfo.processInfo.processIdentifier
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var onScreen = Set<CGWindowID>()
        var pids: [pid_t] = []
        for entry in info {
            guard (entry[kCGWindowLayer as String] as? Int) == 0,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != me, only == nil || pid == only,
                  let id = entry[kCGWindowNumber as String] as? CGWindowID,
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0
            else { continue }
            onScreen.insert(id)
            if !pids.contains(pid) { pids.append(pid) }
        }

        var result: [ManagedWindow] = []
        for pid in pids {
            let app = AXUIElementCreateApplication(pid)
            for window in attribute(app, kAXWindowsAttribute, as: [AXUIElement].self) ?? [] {
                var id: CGWindowID = 0
                guard _AXUIElementGetWindow(window, &id) == .success, onScreen.contains(id),
                      attribute(window, kAXSubroleAttribute, as: String.self) == kAXStandardWindowSubrole,
                      attribute(window, kAXMinimizedAttribute, as: Bool.self) != true,
                      attribute(window, "AXFullScreen", as: Bool.self) != true,
                      let frame = frame(of: window)
                else { continue }
                result.append(ManagedWindow(element: window, app: app, frame: frame))
            }
        }
        return result
    }

    // MARK: - AX helpers

    private func attribute<T>(_ element: AXUIElement, _ name: String, as _: T.Type) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero, size = CGSize.zero
        guard let pos = attribute(window, kAXPositionAttribute, as: AXValue.self),
              let sz = attribute(window, kAXSizeAttribute, as: AXValue.self),
              AXValueGetValue(pos, .cgPoint, &origin), AXValueGetValue(sz, .cgSize, &size)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private func setFrame(_ window: ManagedWindow, _ rect: CGRect) {
        // Chromium/Electron apps animate moves when "enhanced UI" is on, which drops
        // the size change. Turn it off for the move, then put it back.
        let enhanced = attribute(window.app, "AXEnhancedUserInterface", as: Bool.self) == true
        if enhanced { AXUIElementSetAttributeValue(window.app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }

        var origin = rect.origin, size = rect.size
        let pos = AXValueCreate(.cgPoint, &origin)!, sz = AXValueCreate(.cgSize, &size)!
        // Size → position → size: shrinking first lets it fit when crossing displays,
        // and the second size fixes windows clamped by the old display's bounds.
        AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sz)
        AXUIElementSetAttributeValue(window.element, kAXPositionAttribute as CFString, pos)
        AXUIElementSetAttributeValue(window.element, kAXSizeAttribute as CFString, sz)

        if enhanced { AXUIElementSetAttributeValue(window.app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
    }

    // MARK: - Coordinates

    /// AppKit rects are bottom-left based; AX rects are top-left based on the primary display.
    private func axRect(_ r: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    private func screenIndex(for frame: CGRect, in screens: [CGRect]) -> Int {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let i = screens.firstIndex(where: { $0.contains(center) }) { return i }
        // Center is off every display: pick the one the window overlaps most.
        let overlaps = screens.map { s -> CGFloat in let i = s.intersection(frame); return i.isNull ? 0 : i.width * i.height }
        return overlaps.indices.max { overlaps[$0] < overlaps[$1] } ?? 0
    }
}
