import Cocoa
import Carbon.HIToolbox
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    var hotKeyRefFolders: EventHotKeyRef?
    var hotKeyRefExtensions: EventHotKeyRef?
    var hotKeyRefZip: EventHotKeyRef?
    let hotKeyIDFolders = EventHotKeyID(signature: OSType(0x44534C46), id: 1)    // ⌃⇧↑
    let hotKeyIDExtensions = EventHotKeyID(signature: OSType(0x44534C46), id: 2) // ⌃⇧↓
    let hotKeyIDZip = EventHotKeyID(signature: OSType(0x44534C46), id: 3)        // ⌃⇧→

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
        if let ref = hotKeyRefZip {
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
        menu.addItem(NSMenuItem(title: "Zip Folder (no .DS_Store) ⌃⇧→", action: #selector(runZipFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "System Info (copy to clipboard)", action: #selector(copySystemProfilerScript), keyEquivalent: ""))
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
            ("Copy folder as path", "right-click + ⌥"),
            ("Copy file(s) ⌘C", "Paste ⌥⌘V"),
            ("Delete immediately", "⌥⌘⌫"),
            ("Option+ g© iˆ r® y¥", "2™ 3£ 8• 0º =≠"),
            ("Option+ K OØ Tˇ V◊ X˛ Z¸", "|» ?¿ +±"),
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
            switch hkID.id {
            case 1:
                appDelegate.runDeselectFolders()
            case 2:
                appDelegate.runDeselectExtensions()
            case 3:
                appDelegate.runZipFolder()
            default:
                break
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        RegisterEventHotKey(UInt32(kVK_UpArrow), UInt32(controlKey | shiftKey), hotKeyIDFolders, GetApplicationEventTarget(), 0, &hotKeyRefFolders)
        RegisterEventHotKey(UInt32(kVK_DownArrow), UInt32(controlKey | shiftKey), hotKeyIDExtensions, GetApplicationEventTarget(), 0, &hotKeyRefExtensions)
        RegisterEventHotKey(UInt32(kVK_RightArrow), UInt32(controlKey | shiftKey), hotKeyIDZip, GetApplicationEventTarget(), 0, &hotKeyRefZip)
    }


    @objc func runDeselectFolders() {
        deselectFolders()
    }

    @objc func runDeselectExtensions() {
        deselectByExtension(getSavedExtensions())
    }

    @objc func runZipFolder() {
        zipSelectedFolder()
    }

    @objc func copySystemProfilerScript() {
        let script = """
        tmpfile="/tmp/sysinfo.$(date +%Y%m%d_%H%M%S)_$$.txt"

        echo "========= Date =========" >> "$tmpfile"
        echo >> "$tmpfile"
        date >> "$tmpfile"
        echo >> "$tmpfile"

        echo "========= CPU =========" >> "$tmpfile"
        echo >> "$tmpfile"
        sysctl -n machdep.cpu.brand_string >> "$tmpfile"
        echo >> "$tmpfile"

        for section in SPSoftwareDataType SPStorageDataType SPDisplaysDataType SPAudioDataType SPBluetoothDataType SPUSBDataType SPThunderboltDataType SPPowerDataType SPNetworkDataType; do
          echo "========= $section =========" >> "$tmpfile"
          echo >> "$tmpfile"
          system_profiler "$section" >> "$tmpfile"
          echo >> "$tmpfile"
        done

        echo "========= Network Hardware Ports =========" >> "$tmpfile"
        echo >> "$tmpfile"
        networksetup -listallhardwareports >> "$tmpfile"
        echo >> "$tmpfile"

        echo "========= Wi-Fi Info =========" >> "$tmpfile"
        echo >> "$tmpfile"
        networksetup -getinfo Wi-Fi >> "$tmpfile"
        echo >> "$tmpfile"

        echo "========= Wi-Fi DNS Servers =========" >> "$tmpfile"
        echo >> "$tmpfile"
        networksetup -getdnsservers Wi-Fi >> "$tmpfile"
        echo >> "$tmpfile"

        echo "========= Memory (vm_stat) =========" >> "$tmpfile"
        echo >> "$tmpfile"
        vm_stat >> "$tmpfile"
        echo >> "$tmpfile"

        echo "========= Disk Layout (diskutil list) =========" >> "$tmpfile"
        echo >> "$tmpfile"
        diskutil list >> "$tmpfile"
        echo >> "$tmpfile"

        echo "========= Home Folder Sizes =========" >> "$tmpfile"
        echo >> "$tmpfile"
        du -sh ~/Desktop ~/Music ~/Documents ~/Downloads ~/Pictures ~/Movies 2>/dev/null | sort -rh >> "$tmpfile"
        echo >> "$tmpfile"

        echo "========= Brew Installed Apps (30MB+) =========" >> "$tmpfile"
        echo >> "$tmpfile"
        brew_cellar=$(brew --cellar)
        du -sk "$brew_cellar"/*/* 2>/dev/null | awk -v min=30720 '$1 >= min' | sort -rn | awk -F'/' '{
          split($0, a, "\\t")
          size_kb = a[1]
          path = $0
          sub(/^[0-9]+\\t/, "", path)
          n = split(path, parts, "/")
          name = parts[n-1] " " parts[n]
          if (size_kb >= 1048576) {
            printf "%-20s %.1fG\\n", name, size_kb/1048576
          } else {
            printf "%-20s %dM\\n", name, size_kb/1024
          }
        }' >> "$tmpfile"
        echo >> "$tmpfile"

        open -a TextEdit "$tmpfile"
        """
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(script, forType: .string)

        showInfoAlert(title: "Copied", message: "System info script copied — paste into Terminal and press Enter. Report opens automatically in TextEdit.")
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

func zipSelectedFolder() {
    guard let folderPaths = getSelectedFolderPaths() else {
        showErrorAlert(
            title: "Zip Failed",
            message: "Could not read Finder's selection. Make sure Automation access is granted: System Settings → Privacy & Security → Automation → deselectfolders → Finder."
        )
        return
    }

    guard folderPaths.count == 1 else {
        if folderPaths.isEmpty {
            showErrorAlert(title: "No Folder Selected", message: "Select exactly one folder in Finder, then try again.")
        } else {
            showErrorAlert(title: "Too Many Folders Selected", message: "Select exactly one folder. You currently have \(folderPaths.count) folders selected.")
        }
        return
    }

    let folderURL = URL(fileURLWithPath: folderPaths[0])
    let folderName = folderURL.lastPathComponent
    let zipName = "\(folderName).zip"
    let parentURL = folderURL.deletingLastPathComponent()

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.currentDirectoryURL = folderURL
    process.arguments = ["-r", zipName, ".", "-x", "*.DS_Store", "-x", "*__MACOSX*", "-x", zipName]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            // Move the zip from inside the folder to the parent directory
            let sourceZip = folderURL.appendingPathComponent(zipName)
            let destZip = parentURL.appendingPathComponent(zipName)

            do {
                if FileManager.default.fileExists(atPath: destZip.path) {
                    try FileManager.default.removeItem(at: destZip)
                }
                try FileManager.default.moveItem(at: sourceZip, to: destZip)
                showInfoAlert(title: "Zipped", message: "Created \(zipName) in \(parentURL.lastPathComponent)")
            } catch {
                showErrorAlert(title: "Zip Created, Move Failed", message: "\(zipName) was created inside \(folderName) but could not be moved: \(error.localizedDescription)")
            }
        } else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            showErrorAlert(title: "Zip Failed", message: output)
        }
    } catch {
        showErrorAlert(title: "Zip Failed", message: error.localizedDescription)
    }
}

func getSelectedFolderPaths() -> [String]? {
    let script = """
    tell application "Finder"
        set theSelection to selection
        set folderPaths to {}
        repeat with theItem in theSelection
            if (class of theItem is folder) then
                set end of folderPaths to (POSIX path of (theItem as alias))
            end if
        end repeat
        return folderPaths
    end tell
    """
    guard let appleScript = NSAppleScript(source: script) else { return nil }
    var errorDict: NSDictionary?
    let result = appleScript.executeAndReturnError(&errorDict)
    if errorDict != nil {
        return nil
    }

    var paths: [String] = []
    if result.numberOfItems > 0 {
        for i in 1...result.numberOfItems {
            if let item = result.atIndex(i), let str = item.stringValue {
                paths.append(str)
            }
        }
    }
    return paths
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

func showErrorAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func showInfoAlert(title: String, message: String) {
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.runModal()
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
