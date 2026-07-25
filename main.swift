import Cocoa
import Carbon.HIToolbox
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    var hotKeyRefFolders: EventHotKeyRef?
    var hotKeyRefExtensions: EventHotKeyRef?
    let hotKeyIDFolders = EventHotKeyID(signature: OSType(0x44534C46), id: 1)    // ⌃⇧↑
    let hotKeyIDExtensions = EventHotKeyID(signature: OSType(0x44534C46), id: 2) // ⌃⇧↓

    let defaults = UserDefaults.standard
    let extensionsKey = "deselectExtensions"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerHotKeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let ref = hotKeyRefFolders {
            UnregisterEventHotKey(ref)
        }
        if let ref = hotKeyRefExtensions {
            UnregisterEventHotKey(ref)
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.badge.minus", accessibilityDescription: "Deselect Folders")
        }

        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Deselect Folders  ⌃⇧↑", action: #selector(runDeselectFolders), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Deselect by Extension  ⌃⇧↓", action: #selector(runDeselectExtensions), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Edit Extensions…", action: #selector(editExtensions), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let referenceTitle = NSMenuItem(title: "Finder Shortcuts", action: nil, keyEquivalent: "")
        referenceTitle.isEnabled = false
        menu.addItem(referenceTitle)

        let shortcuts: [(String, String)] = [
            ("Select all + expand", "⌘A"),
            ("Expand selected folders", "⌘→"),
            ("Collapse selected folders", "⌘←"),
            ("Expand everything recursively", "⌥⌘→"),
            ("Toggle hidden files", "⌘⇧."),
            ("Copy folder as path", "right-click + ⌥")
        ]

        for (label, keys) in shortcuts {
            let item = NSMenuItem(title: "\(label)   \(keys)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.indentationLevel = 1
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { if $0.action != nil { $0.target = self } }
        statusItem.menu = menu
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func registerHotKeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)

            let appDelegate = Unmanaged<AppDelegate>.fromOpaque(userData!).takeUnretainedValue()
            if hkID.id == 1 {
                appDelegate.runDeselectFolders()
            } else if hkID.id == 2 {
                appDelegate.runDeselectExtensions()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        RegisterEventHotKey(UInt32(kVK_UpArrow), UInt32(controlKey | shiftKey), hotKeyIDFolders, GetApplicationEventTarget(), 0, &hotKeyRefFolders)
        RegisterEventHotKey(UInt32(kVK_DownArrow), UInt32(controlKey | shiftKey), hotKeyIDExtensions, GetApplicationEventTarget(), 0, &hotKeyRefExtensions)
    }

    @objc func runDeselectFolders() {
        deselectFolders()
    }

    @objc func runDeselectExtensions() {
        deselectByExtension(getSavedExtensions())
    }

    @objc func editExtensions() {
        let alert = NSAlert()
        alert.messageText = "File Extensions to Deselect"
        alert.informativeText = "Comma-separated, no dots (e.g. jpg, pdf, png)"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = defaults.string(forKey: extensionsKey) ?? "jpg, pdf"
        alert.accessoryView = input
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            saveExtensions(input.stringValue)
        }
    }

    func getSavedExtensions() -> [String] {
        let raw = defaults.string(forKey: extensionsKey) ?? "jpg, pdf"
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
    }

    func saveExtensions(_ text: String) {
        defaults.set(text, forKey: extensionsKey)
    }
}

func deselectFolders() {
    guard AXIsProcessTrusted() else {
        showAccessibilityAlert()
        return
    }

    guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
        return
    }
    let appElement = AXUIElementCreateApplication(finder.processIdentifier)
    var windowValue: CFTypeRef?
    AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
    guard let window = windowValue else { return }

    var outlines: [AXUIElement] = []
    findAllOutlines(in: window as! AXUIElement, results: &outlines)
    guard outlines.count >= 2 else { return }

    let outline = outlines[1]
    var rowsValue: CFTypeRef?
    AXUIElementCopyAttributeValue(outline, kAXRowsAttribute as CFString, &rowsValue)
    guard let rows = rowsValue as? [AXUIElement] else { return }

    for row in rows {
        var selectedValue: CFTypeRef?
        AXUIElementCopyAttributeValue(row, kAXSelectedAttribute as CFString, &selectedValue)
        guard (selectedValue as? Bool) ?? false else { continue }

        if isFolder(row) {
            AXUIElementSetAttributeValue(row, kAXSelectedAttribute as CFString, false as CFTypeRef)
        }
    }
}

func deselectByExtension(_ extensions: [String]) {
    guard AXIsProcessTrusted() else {
        showAccessibilityAlert()
        return
    }
    guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
        return
    }

    let appElement = AXUIElementCreateApplication(finder.processIdentifier)
    var windowValue: CFTypeRef?
    AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue)
    guard let window = windowValue else { return }

    var outlines: [AXUIElement] = []
    findAllOutlines(in: window as! AXUIElement, results: &outlines)
    guard outlines.count >= 2 else { return }

    let outline = outlines[1]
    var rowsValue: CFTypeRef?
    AXUIElementCopyAttributeValue(outline, kAXRowsAttribute as CFString, &rowsValue)
    guard let rows = rowsValue as? [AXUIElement] else { return }

    for row in rows {
        var selectedValue: CFTypeRef?
        AXUIElementCopyAttributeValue(row, kAXSelectedAttribute as CFString, &selectedValue)
        guard (selectedValue as? Bool) ?? false else { continue }

        guard let name = getRowName(row), let ext = fileExtension(of: name) else { continue }

        if extensions.contains(ext) {
            AXUIElementSetAttributeValue(row, kAXSelectedAttribute as CFString, false as CFTypeRef)
        }
    }
}

func showAccessibilityAlert() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "Grant deselectfolders access in System Settings → Privacy & Security → Accessibility, then try again."
    alert.addButton(withTitle: "Open Settings")
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

func isFolder(_ row: AXUIElement) -> Bool {
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(row, kAXChildrenAttribute as CFString, &childrenValue)
    guard let cells = childrenValue as? [AXUIElement] else { return false }
    for cell in cells {
        var cellChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(cell, kAXChildrenAttribute as CFString, &cellChildren)
        guard let children = cellChildren as? [AXUIElement] else { continue }
        for child in children {
            var roleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
            if let role = roleValue as? String, role == "AXDisclosureTriangle" {
                return true
            }
        }
    }
    return false
}

func getRowName(_ row: AXUIElement) -> String? {
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(row, kAXChildrenAttribute as CFString, &childrenValue)
    guard let cells = childrenValue as? [AXUIElement] else { return nil }
    for cell in cells {
        var cellChildren: CFTypeRef?
        AXUIElementCopyAttributeValue(cell, kAXChildrenAttribute as CFString, &cellChildren)
        guard let children = cellChildren as? [AXUIElement] else { continue }
        for child in children {
            var roleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue)
            if let role = roleValue as? String, role == "AXTextField" {
                var valueRef: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &valueRef)
                return valueRef as? String
            }
        }
    }
    return nil
}

func fileExtension(of name: String) -> String? {
    let parts = name.split(separator: ".")
    guard parts.count > 1 else { return nil }
    return parts.last?.lowercased()
}

func findAllOutlines(in element: AXUIElement, results: inout [AXUIElement]) {
    var roleValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
    if let role = roleValue as? String, role == "AXOutline" {
        results.append(element)
    }
    var childrenValue: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
    guard let children = childrenValue as? [AXUIElement] else { return }
    for child in children {
        findAllOutlines(in: child, results: &results)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
