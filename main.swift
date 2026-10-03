import Cocoa
import Carbon.HIToolbox
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var progressMenuItem: NSMenuItem!
    var cancelMenuItem: NSMenuItem!
    var sortMenuItems: [CopySortMode: NSMenuItem] = [:]
    var openInTextEditItem: NSMenuItem!
    var hotKeyRefDurations: EventHotKeyRef?
    var hotKeyRefDurationsBinary: EventHotKeyRef?
    var hotKeyRefDurationsDecimal: EventHotKeyRef?
    var hotKeyRefFolders: EventHotKeyRef?
    var hotKeyRefExtensions: EventHotKeyRef?
    var hotKeyRefZip: EventHotKeyRef?
    var hotKeyRefInvert: EventHotKeyRef?
    var hotKeyRefCopyNames: EventHotKeyRef?
    var hotKeyRefCopyNamesDecimal: EventHotKeyRef?
    var hotKeyRefNewFile: EventHotKeyRef?
    let hotKeyIDFolders = EventHotKeyID(signature: OSType(0x44534C46), id: 1)    // ⌃⇧↑
    let hotKeyIDExtensions = EventHotKeyID(signature: OSType(0x44534C46), id: 2) // ⌃⇧↓
    let hotKeyIDZip = EventHotKeyID(signature: OSType(0x44534C46), id: 3)        // ⌃⇧→
    let hotKeyIDInvert = EventHotKeyID(signature: OSType(0x44534C46), id: 4)     // ⌃⇧←
    let hotKeyIDCopyNames = EventHotKeyID(signature: OSType(0x44534C46), id: 5)  // ⌃⇧C
    let hotKeyIDCopyNamesDecimal = EventHotKeyID(signature: OSType(0x44534C46), id: 6)  // ⌃⇧⌥↑
    let hotKeyIDNewFile = EventHotKeyID(signature: OSType(0x44534C46), id: 7)  // ⌃⇧⌥N
    let hotKeyIDDurations = EventHotKeyID(signature: OSType(0x44534C46), id: 8)         // ⌃⇧⌥↓
    let hotKeyIDDurationsBinary = EventHotKeyID(signature: OSType(0x44534C46), id: 9)   // ⌃⇧⌥←
    let hotKeyIDDurationsDecimal = EventHotKeyID(signature: OSType(0x44534C46), id: 10) // ⌃⇧⌥→


    let defaults = UserDefaults.standard
    let extensionsKey = "deselectExtensions"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        registerHotKeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let ref = hotKeyRefFolders {UnregisterEventHotKey(ref)}
        if let ref = hotKeyRefExtensions {UnregisterEventHotKey(ref)}
        if let ref = hotKeyRefZip {UnregisterEventHotKey(ref)}
        if let ref = hotKeyRefInvert {UnregisterEventHotKey(ref)}
        if let ref = hotKeyRefCopyNames {UnregisterEventHotKey(ref)}
        if let ref = hotKeyRefCopyNamesDecimal {UnregisterEventHotKey(ref)}
        if let ref = hotKeyRefNewFile {UnregisterEventHotKey(ref)}
        if let ref = hotKeyRefDurations { UnregisterEventHotKey(ref) }
        if let ref = hotKeyRefDurationsBinary { UnregisterEventHotKey(ref) }
        if let ref = hotKeyRefDurationsDecimal { UnregisterEventHotKey(ref) }
    }


    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.badge.minus", accessibilityDescription: "Deselect Folders")
        }

        let menu = NSMenu()

        progressMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        progressMenuItem.isEnabled = false
        progressMenuItem.isHidden = true
        menu.addItem(progressMenuItem)

        cancelMenuItem = NSMenuItem(title: "Cancel Zipping", action: #selector(cancelZipping), keyEquivalent: "")
        cancelMenuItem.isHidden = true
        menu.addItem(cancelMenuItem)

        menu.addItem(NSMenuItem(title: "Deselect Folders  ⌃⇧↑", action: #selector(runDeselectFolders), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Deselect by Extension  ⌃⇧↓", action: #selector(runDeselectExtensions), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Invert Selection  ⌃⇧←", action: #selector(runInvertSelection), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Edit Extensions…", action: #selector(editExtensions), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Zip Selected Folders (no hidden Mac files) ⌃⇧→", action: #selector(runZipFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "New Empty Text File  ⌃⇧⌥N", action: #selector(runNewFile), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem.separator())
        let sortHeader = NSMenuItem(title: "Sort Copy Names / Durations", action: nil, keyEquivalent: "")
        sortHeader.isEnabled = false
        menu.addItem(sortHeader)

        let sortOptions: [(CopySortMode, String)] = [
            (.abc, "Sort: ABC"),
            (.descending, "Sort ↓ (largest / longest first)"),
            (.ascending, "Sort ↑ (smallest / shortest first)")
        ]
        for (mode, title) in sortOptions {
            let item = NSMenuItem(title: title, action: #selector(setSortMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.indentationLevel = 1
            sortMenuItems[mode] = item
            menu.addItem(item)
        }
        updateSortChecks()
        openInTextEditItem = NSMenuItem(title: "Open Results in TextEdit", action: #selector(toggleOpenInTextEdit), keyEquivalent: "")
        openInTextEditItem.state = UserDefaults.standard.bool(forKey: "openInTextEdit") ? .on : .off
        menu.addItem(openInTextEditItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Copy Names + Sizes KiB/MiB/GiB  ⌃⇧C", action: #selector(runCopyNames), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Names + Sizes (KB/MB/GB)  ⌃⇧⌥↑", action: #selector(runCopyNamesDecimal), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Copy Media Durations (no sizes)  ⌃⇧⌥↓", action: #selector(runCopyDurations), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Media Durations KiB/MiB/GiB  ⌃⇧⌥←", action: #selector(runCopyDurationsBinary), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Media Durations KB/MB/GB  ⌃⇧⌥→", action: #selector(runCopyDurationsDecimal), keyEquivalent: ""))
        let ffmpegNote = NSMenuItem(title: "(brew install ffmpeg)", action: nil, keyEquivalent: "")
        ffmpegNote.isEnabled = false
        ffmpegNote.indentationLevel = 1
        menu.addItem(ffmpegNote)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "System Info (copy/paste in Terminal)", action: #selector(copySystemProfilerScript), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let referenceTitle = NSMenuItem(title: "Finder Shortcuts", action: nil, keyEquivalent: "")
        referenceTitle.isEnabled = false
        menu.addItem(referenceTitle)

        let shortcuts: [(String, String)] = [
            ("Expand/Collapse selected folders", "⌘→ / ⌘←"),
            ("Expand everything recursively", "⌥⌘→"),
            ("Toggle hidden files", "⌘⇧."),
            ("Copy folder as path", "right-click + ⌥"),
            ("Copy file(s) ⌘C", "Paste (move files) ⌥⌘V"),
            ("Delete immediately", "⌥⌘⌫"),
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
            case 4:
                appDelegate.runInvertSelection()
            case 5:
                appDelegate.runCopyNames()
            case 6:
                appDelegate.runCopyNamesDecimal()
            case 7:
                appDelegate.runNewFile()
            case 8:
                appDelegate.runCopyDurations()
            case 9:
                appDelegate.runCopyDurationsBinary()
            case 10:
                appDelegate.runCopyDurationsDecimal()
            default:
                break
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        RegisterEventHotKey(UInt32(kVK_UpArrow), UInt32(controlKey | shiftKey), hotKeyIDFolders, GetApplicationEventTarget(), 0, &hotKeyRefFolders)
        RegisterEventHotKey(UInt32(kVK_DownArrow), UInt32(controlKey | shiftKey), hotKeyIDExtensions, GetApplicationEventTarget(), 0, &hotKeyRefExtensions)
        RegisterEventHotKey(UInt32(kVK_RightArrow), UInt32(controlKey | shiftKey), hotKeyIDZip, GetApplicationEventTarget(), 0, &hotKeyRefZip)
        RegisterEventHotKey(UInt32(kVK_LeftArrow), UInt32(controlKey | shiftKey), hotKeyIDInvert, GetApplicationEventTarget(), 0, &hotKeyRefInvert)
        RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(controlKey | shiftKey), hotKeyIDCopyNames, GetApplicationEventTarget(), 0, &hotKeyRefCopyNames)
        RegisterEventHotKey(UInt32(kVK_UpArrow), UInt32(controlKey | shiftKey | optionKey), hotKeyIDCopyNamesDecimal, GetApplicationEventTarget(), 0, &hotKeyRefCopyNamesDecimal)
        RegisterEventHotKey(UInt32(kVK_ANSI_N), UInt32(controlKey | shiftKey | optionKey), hotKeyIDNewFile, GetApplicationEventTarget(), 0, &hotKeyRefNewFile)
        RegisterEventHotKey(UInt32(kVK_DownArrow), UInt32(controlKey | shiftKey | optionKey), hotKeyIDDurations, GetApplicationEventTarget(), 0, &hotKeyRefDurations)
        RegisterEventHotKey(UInt32(kVK_LeftArrow), UInt32(controlKey | shiftKey | optionKey), hotKeyIDDurationsBinary, GetApplicationEventTarget(), 0, &hotKeyRefDurationsBinary)
        RegisterEventHotKey(UInt32(kVK_RightArrow), UInt32(controlKey | shiftKey | optionKey), hotKeyIDDurationsDecimal, GetApplicationEventTarget(), 0, &hotKeyRefDurationsDecimal)
    }


    @objc func runDeselectFolders() {
        deselectFolders()
    }

    @objc func runDeselectExtensions() {
        deselectByExtension(getSavedExtensions())
    }

    @objc func runInvertSelection() {
        invertSelection()
    }

    @objc func runCopyNames() {
        copySelectedNamesWithSizes(decimal: false)
    }

    @objc func runCopyNamesDecimal() {
        copySelectedNamesWithSizes(decimal: true)
    }

    @objc func runZipFolder() {
        zipSelectedFolders()
    }

    @objc func runCopyDurations() {
        copyMediaDurations(sizeMode: .none)
    }

    @objc func runCopyDurationsBinary() {
        copyMediaDurations(sizeMode: .binary)
    }

    @objc func runCopyDurationsDecimal() {
        copyMediaDurations(sizeMode: .decimal)
    }

    @objc func runNewFile() {
        createNewTextFile()
    }

    @objc func setSortMode(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String {
            UserDefaults.standard.set(raw, forKey: "copySortMode")
            updateSortChecks()
        }
    }

    func updateSortChecks() {
        let current = currentSortMode()
        for (mode, item) in sortMenuItems {
            item.state = (mode == current) ? .on : .off
        }
    }

    @objc func toggleOpenInTextEdit() {
        let newValue = !UserDefaults.standard.bool(forKey: "openInTextEdit")
        UserDefaults.standard.set(newValue, forKey: "openInTextEdit")
        openInTextEditItem.state = newValue ? .on : .off
    }

    // MARK: - Zip progress UI

    private func monoAttributed(_ text: String) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        return NSAttributedString(string: text, attributes: [.font: font])
    }

    private func pad(_ n: Int, width: Int) -> String {
        let s = String(n)
        return String(repeating: " ", count: max(0, width - s.count)) + s
    }

    private func setProgressText(bar: String, menu: String) {
        statusItem.button?.attributedTitle = monoAttributed(bar)
        progressMenuItem.attributedTitle = monoAttributed(menu)
    }

    func beginProgress() {
        statusItem.length = NSStatusItem.variableLength
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "archivebox.fill", accessibilityDescription: "Zipping")
            button.imagePosition = .imageLeft
        }
        setProgressText(bar: " Preparing…", menu: "Preparing…")
        progressMenuItem.isHidden = false
        cancelMenuItem.isHidden = false
    }

    func updateProgress(index: Int, total: Int, name: String, percent: Int) {
        let w = String(total).count
        let bar = " \(pad(index, width: w))/\(total) \(pad(percent, width: 3))%"
        let menu = "Zipping \(pad(index, width: w)) of \(total): \(name) — \(pad(percent, width: 3))%"
        setProgressText(bar: bar, menu: menu)
    }

    func endProgress() {
        statusItem.length = NSStatusItem.squareLength
        if let button = statusItem.button {
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            button.image = NSImage(systemSymbolName: "folder.badge.minus", accessibilityDescription: "Deselect Folders")
        }
        progressMenuItem.attributedTitle = nil
        progressMenuItem.isHidden = true
        cancelMenuItem.isHidden = true
    }

    @objc func cancelZipping() {
        zipLock.lock()
        zipCancelRequested = true
        currentZipProcess?.terminate()
        zipLock.unlock()
        progressMenuItem.attributedTitle = monoAttributed("Cancelling…")
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

func invertSelection() {
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

    var unselected: [AXUIElement] = []
    for row in rows {
        var selectedValue: CFTypeRef?
        AXUIElementCopyAttributeValue(row, kAXSelectedAttribute as CFString, &selectedValue)
        if !((selectedValue as? Bool) ?? false) {
            unselected.append(row)
        }
    }

    AXUIElementSetAttributeValue(outline, kAXSelectedRowsAttribute as CFString, unselected as CFTypeRef)
}

// MARK: - Zipping

// Hidden macOS files/folders to leave out of archives
let zipExcludes: [String] = [
    "*.DS_Store",
    "*/.DS_Store",
    "*/__MACOSX/*",
    "__MACOSX/*",
    "*/._*",
    "._*",
    "*/.AppleDouble/*",
    "*/.Spotlight-V100/*",
    "*/.Trashes/*",
    "*/.fseventsd/*",
    "*/.TemporaryItems/*",
    "*/.localized",
    "*/.VolumeIcon.icns",
    "*/Icon\r"
]

var isZipping = false

// Shared state so the Cancel menu item can stop the running zip
let zipLock = NSLock()
var currentZipProcess: Process?
var zipCancelRequested = false

func zipSelectedFolders() {
    if isZipping {
        showErrorAlert(title: "Zip In Progress", message: "Please wait for the current zip operation to finish, or choose Cancel Zipping from the menu.")
        return
    }

    guard let folderPaths = getSelectedFolderPaths() else {
        showErrorAlert(
            title: "Zip Failed",
            message: "Could not read Finder's selection. Make sure Automation access is granted: System Settings → Privacy & Security → Automation → deselectfolders → Finder."
        )
        return
    }

    guard !folderPaths.isEmpty else {
        showErrorAlert(title: "No Folder Selected", message: "Select one or more folders in Finder, then try again.")
        return
    }

    isZipping = true
    zipLock.lock()
    zipCancelRequested = false
    zipLock.unlock()

    let appDelegate = NSApp.delegate as? AppDelegate
    appDelegate?.beginProgress()

    DispatchQueue.global(qos: .userInitiated).async {
        var succeeded: [String] = []
        var failures: [String] = []
        var cancelled = false
        let total = folderPaths.count

        for (i, path) in folderPaths.enumerated() {
            zipLock.lock()
            let stop = zipCancelRequested
            zipLock.unlock()
            if stop { cancelled = true; break }

            let folderURL = URL(fileURLWithPath: path).standardizedFileURL
            let name = folderURL.lastPathComponent

            DispatchQueue.main.async {
                appDelegate?.updateProgress(index: i + 1, total: total, name: name, percent: 0)
            }

            let result = zipFolder(at: folderURL) { percent in
                DispatchQueue.main.async {
                    appDelegate?.updateProgress(index: i + 1, total: total, name: name, percent: percent)
                }
            }

            if result.cancelled {
                cancelled = true
                break
            } else if result.success {
                succeeded.append(name)
            } else {
                failures.append("\(name): \(result.message)")
            }
        }

        DispatchQueue.main.async {
            isZipping = false
            appDelegate?.endProgress()

            if cancelled {
                showInfoAlert(title: "Cancelled", message: "Zipping was cancelled. Completed before cancelling: \(succeeded.count) of \(total).")
            } else if failures.isEmpty {
                let msg = succeeded.count == 1
                    ? "Created \(succeeded[0]).zip"
                    : "Created \(succeeded.count) zip files next to the original folders."
                showInfoAlert(title: "Zipped", message: msg)
            } else {
                var msg = failures.joined(separator: "\n")
                if !succeeded.isEmpty {
                    msg = "Succeeded: \(succeeded.count)\nFailed: \(failures.count)\n\n" + msg
                }
                showErrorAlert(title: "Zip Failed", message: msg)
            }
        }
    }
}

/// Counts the files zip is expected to add (skips the hidden Mac files we exclude).
func countFiles(in folderURL: URL) -> Int {
    guard let enumerator = FileManager.default.enumerator(
        at: folderURL,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: []
    ) else { return 0 }

    let skipDirs: Set<String> = ["__MACOSX", ".AppleDouble", ".Spotlight-V100", ".Trashes", ".fseventsd", ".TemporaryItems"]
    var count = 0

    for case let url as URL in enumerator {
        let name = url.lastPathComponent
        if skipDirs.contains(name) {
            enumerator.skipDescendants()
            continue
        }
        if name == ".DS_Store" || name == ".localized" || name == ".VolumeIcon.icns" || name.hasPrefix("._") {
            continue
        }
        if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            continue
        }
        count += 1
    }
    return count
}

/// True if a line of zip output is a file (not a directory) being added.
func isFileEntry(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespaces)
    guard t.hasPrefix("adding: ") || t.hasPrefix("updating: ") else { return false }
    guard let r = t.range(of: " (", options: .backwards) else { return true }
    return !t[..<r.lowerBound].hasSuffix("/")
}

/// Zips one folder into "<parent>/<folderName>.zip". Call from a background thread.
/// onProgress receives 0...99 as files are added.
func zipFolder(at folderURL: URL, onProgress: @escaping (Int) -> Void)
    -> (success: Bool, cancelled: Bool, message: String) {

    let folderName = folderURL.lastPathComponent
    let zipName = "\(folderName).zip"
    let parentURL = folderURL.deletingLastPathComponent()
    let destZip = parentURL.appendingPathComponent(zipName)

    // Remove any old zip so zip creates a fresh archive instead of updating it
    if FileManager.default.fileExists(atPath: destZip.path) {
        do {
            try FileManager.default.removeItem(at: destZip)
        } catch {
            return (false, false, "Could not replace existing zip: \(error.localizedDescription)")
        }
    }

    let totalFiles = max(countFiles(in: folderURL), 1)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.currentDirectoryURL = parentURL
    process.arguments = ["-r", zipName, folderName, "-x"] + zipExcludes

    // stdout and stderr share one pipe that we read continuously (no deadlock)
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        return (false, false, error.localizedDescription)
    }

    zipLock.lock()
    currentZipProcess = process
    if zipCancelRequested { process.terminate() }
    zipLock.unlock()

    var buffer = Data()
    var filesDone = 0
    var lastPercent = 0
    var errorText = ""
    let handle = pipe.fileHandleForReading

    while true {
        let chunk = handle.availableData
        if chunk.isEmpty { break }   // EOF: zip exited
        buffer.append(chunk)

        while let nl = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer.subdata(in: buffer.startIndex..<nl)
            buffer.removeSubrange(buffer.startIndex...nl)
            let line = String(data: lineData, encoding: .utf8) ?? ""

            if isFileEntry(line) {
                filesDone += 1
                let percent = min(99, filesDone * 100 / totalFiles)
                if percent != lastPercent {
                    lastPercent = percent
                    onProgress(percent)
                }
            } else if !line.trimmingCharacters(in: .whitespaces).hasPrefix("adding:")
                        && !line.isEmpty
                        && errorText.count < 4000 {
                errorText += line + "\n"
            }
        }
    }

    process.waitUntilExit()

    zipLock.lock()
    currentZipProcess = nil
    let wasCancelled = zipCancelRequested
    zipLock.unlock()

    if wasCancelled {
        try? FileManager.default.removeItem(at: destZip)
        return (false, true, "Cancelled")
    }

    if process.terminationStatus == 0 {
        return (true, false, "")
    } else {
        try? FileManager.default.removeItem(at: destZip)
        let msg = errorText.isEmpty ? "zip exited with code \(process.terminationStatus)" : errorText
        return (false, false, msg)
    }
}

// MARK: - Copy names + sizes

/// Paths of everything selected in Finder (files and folders).
func getSelectedItemPaths() -> [String]? {
    let script = """
    tell application "Finder"
        set thePaths to {}
        repeat with theItem in (get selection)
            set end of thePaths to (POSIX path of (theItem as alias))
        end repeat
        return thePaths
    end tell
    """
    guard let appleScript = NSAppleScript(source: script) else { return nil }
    var errorDict: NSDictionary?
    let result = appleScript.executeAndReturnError(&errorDict)
    if errorDict != nil { return nil }

    var paths: [String] = []
    if result.numberOfItems > 0 {
        for i in 1...result.numberOfItems {
            if let str = result.atIndex(i)?.stringValue {
                paths.append(str)
            }
        }
    }
    return paths
}

/// File size, or the recursive total for a folder.
func totalSize(of url: URL) -> UInt64 {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

    if !isDir.boolValue {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return UInt64(size)
    }

    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        options: []
    ) else { return 0 }

    var total: UInt64 = 0
    for case let fileURL as URL in enumerator {
        let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        if values?.isRegularFile == true, let size = values?.fileSize {
            total += UInt64(size)
        }
    }
    return total
}

/// Binary: 1.15GiB / 563.1MiB / 357.0KiB   Decimal: 1.23GB / 580.2MB / 365.5KB
func formatSize(_ bytes: UInt64, decimal: Bool = false) -> String {
    let b = Double(bytes)
    let k: Double = decimal ? 1_000 : 1_024
    let m = k * k
    let g = m * k

    if b >= g { return String(format: decimal ? "%.2fGB"  : "%.2fGiB", b / g) }
    if b >= m { return String(format: decimal ? "%.1fMB"  : "%.1fMiB", b / m) }
    if b >= k { return String(format: decimal ? "%.1fKB"  : "%.1fKiB", b / k) }
    return "\(bytes)B"
}

func copySelectedNamesWithSizes(decimal: Bool = false) {
    guard let paths = getSelectedItemPaths() else {
        showErrorAlert(
            title: "Copy Failed",
            message: "Could not read Finder's selection. Make sure Automation access is granted: System Settings → Privacy & Security → Automation → deselectfolders → Finder."
        )
        return
    }
    guard !paths.isEmpty else {
        NSSound.beep()
        return
    }

    let sortMode = currentSortMode()

    DispatchQueue.global(qos: .userInitiated).async {
        let urls = paths
            .map { URL(fileURLWithPath: $0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        let sizes = urls.map { totalSize(of: $0) }
        let totalBytes = sizes.reduce(0, +)

        var order = Array(urls.indices)   // already in name order
        if sortMode != .abc {
            order.sort { a, b in
                if sizes[a] != sizes[b] {
                    return sortMode == .descending ? sizes[a] > sizes[b] : sizes[a] < sizes[b]
                }
                return a < b
            }
        }

        var lines: [String] = []
        for i in order {
            let name = urls[i].lastPathComponent
            let size = formatSize(sizes[i], decimal: decimal)
            lines.append("\(size) \(name)")
        }

        let binary = formatSize(totalBytes, decimal: false)
        let si = formatSize(totalBytes, decimal: true)
        lines.append(decimal ? "Total \(si) or \(binary)" : "Total \(binary) or \(si)")

        let text = lines.joined(separator: "\n")

        DispatchQueue.main.async {
            deliverOutput(text, baseName: "names")
        }
    }
}

// MARK: - Media durations

enum DurationSizeMode {
    case none, binary, decimal
}

let mediaExtensions: Set<String> = [
    // audio
    "opus", "mp3", "m4a", "flac", "aac", "wav", "ogg", "oga", "wma", "aiff", "aif",
    // video
    "mp4", "m4v", "mov", "mkv", "avi", "webm", "wmv", "flv", "ts", "mpg", "mpeg"
]

/// GUI apps don't inherit your shell PATH, so check the usual Homebrew locations.
func findFFprobe() -> String? {
    let candidates = ["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe", "/usr/bin/ffprobe"]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

/// All media files at a URL: the file itself, or every media file inside a folder.
func mediaFiles(at url: URL) -> [URL] {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }

    if !isDir.boolValue {
        return mediaExtensions.contains(url.pathExtension.lowercased()) ? [url] : []
    }

    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]   // skips .DS_Store and ._* files
    ) else { return [] }

    var results: [URL] = []
    for case let fileURL as URL in enumerator {
        guard mediaExtensions.contains(fileURL.pathExtension.lowercased()) else { continue }
        if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
            results.append(fileURL)
        }
    }
    return results
}

/// Duration in seconds via ffprobe, or 0 if it can't be read.
func mediaDuration(of url: URL, ffprobe: String) -> Double {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ffprobe)
    process.arguments = ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", url.path]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    do { try process.run() } catch { return 0 }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()   // read before waiting
    process.waitUntilExit()

    let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return Double(text) ?? 0
}

/// 58h 35m  (under an hour: 3m 20s)
func formatDuration(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 { return String(format: "%dh %02dm", h, m) }
    return String(format: "%dm %02ds", m, s)
}

func copyMediaDurations(sizeMode: DurationSizeMode) {
    guard let ffprobe = findFFprobe() else {
        showErrorAlert(
            title: "ffprobe Not Found",
            message: "Media durations need ffmpeg. Install it in Terminal with:\n\nbrew install ffmpeg"
        )
        return
    }
    guard let paths = getSelectedItemPaths() else {
        showErrorAlert(
            title: "Copy Failed",
            message: "Could not read Finder's selection. Make sure Automation access is granted: System Settings → Privacy & Security → Automation → deselectfolders → Finder."
        )
        return
    }
    guard !paths.isEmpty else {
        NSSound.beep()
        return
    }

    DispatchQueue.global(qos: .userInitiated).async {
        let urls = paths
            .map { URL(fileURLWithPath: $0) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        // Gather every media file, remembering which selected item it belongs to
        var allFiles: [URL] = []
        var owner: [Int] = []
        for (i, url) in urls.enumerated() {
            let files = mediaFiles(at: url)
            allFiles.append(contentsOf: files)
            owner.append(contentsOf: Array(repeating: i, count: files.count))
        }

        // Run ffprobe on many files at once
        var durations = [Double](repeating: 0, count: allFiles.count)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: allFiles.count) { i in
            let d = mediaDuration(of: allFiles[i], ffprobe: ffprobe)
            lock.lock()
            durations[i] = d
            lock.unlock()
        }

        var perItem = [Double](repeating: 0, count: urls.count)
        var mediaCount = [Int](repeating: 0, count: urls.count)
        for (i, d) in durations.enumerated() {
            perItem[owner[i]] += d
            mediaCount[owner[i]] += 1
        }

        var sizes = [UInt64](repeating: 0, count: urls.count)
        if sizeMode != .none {
            sizes = urls.map { totalSize(of: $0) }
        }

        let sortMode = currentSortMode()
        let decimal = (sizeMode == .decimal)

        var order = Array(urls.indices)   // already in name order
        if sortMode != .abc {
            order.sort { a, b in
                if perItem[a] != perItem[b] {
                    return sortMode == .descending ? perItem[a] > perItem[b] : perItem[a] < perItem[b]
                }
                return a < b
            }
        }

        var lines: [String] = []
        for i in order {
            let name = urls[i].lastPathComponent
            let duration = mediaCount[i] == 0 ? "no media" : formatDuration(perItem[i])
            let sizeText = sizeMode == .none ? "" : formatSize(sizes[i], decimal: decimal)

            // Always: duration name size  (size omitted for "no sizes")
            let parts = [duration, name, sizeText]
            lines.append(parts.filter { !$0.isEmpty }.joined(separator: " "))
        }

        let totalDuration = formatDuration(perItem.reduce(0, +))
        switch sizeMode {
        case .none:
            lines.append("Total \(totalDuration)")
        case .binary, .decimal:
            let totalBytes = sizes.reduce(0, +)
            let binary = formatSize(totalBytes, decimal: false)
            let si = formatSize(totalBytes, decimal: true)
            lines.append(sizeMode == .binary
                ? "Total \(binary) or \(si) \(totalDuration)"
                : "Total \(si) or \(binary) \(totalDuration)")
        }

        let text = lines.joined(separator: "\n")

        DispatchQueue.main.async {
            deliverOutput(text, baseName: "durations")
        }
    }
}

// MARK: - New empty text file

/// Folder of the front Finder window, or the Desktop if no window is open.
func getFrontFinderFolderPath() -> String? {
    let script = """
    tell application "Finder"
        try
            return POSIX path of (target of front Finder window as alias)
        on error
            return POSIX path of (path to desktop folder)
        end try
    end tell
    """
    guard let appleScript = NSAppleScript(source: script) else { return nil }
    var errorDict: NSDictionary?
    let result = appleScript.executeAndReturnError(&errorDict)
    if errorDict != nil { return nil }
    return result.stringValue
}

func selectInFinder(_ url: URL) {
    let escaped = url.path
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    let script = """
    tell application "Finder"
        activate
        select (POSIX file "\(escaped)" as alias)
    end tell
    """
    var errorDict: NSDictionary?
    NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
}

/// Presses Return with no modifiers (Finder treats Return on a selected item as Rename).
func pressReturnKey() {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Return), keyDown: down)
        event?.flags = []   // don't inherit ⌃⇧ from the hotkey that's still held
        event?.post(tap: .cghidEventTap)
    }
}

func createNewTextFile() {
    guard let folderPath = getFrontFinderFolderPath() else {
        showErrorAlert(
            title: "New File Failed",
            message: "Could not read Finder's window. Make sure Automation access is granted: System Settings → Privacy & Security → Automation → deselectfolders → Finder."
        )
        return
    }

    let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
    let fm = FileManager.default

    // untitled.txt, then untitled 2.txt, untitled 3.txt ...
    var fileURL = folderURL.appendingPathComponent("untitled.txt")
    var n = 2
    while fm.fileExists(atPath: fileURL.path) {
        fileURL = folderURL.appendingPathComponent("untitled \(n).txt")
        n += 1
    }

    guard fm.createFile(atPath: fileURL.path, contents: Data(), attributes: nil) else {
        showErrorAlert(title: "New File Failed", message: "Could not create a file in \(folderURL.lastPathComponent). Check that you have write permission there.")
        return
    }

    selectInFinder(fileURL)

    // Give Finder a moment to come forward and select the file, then start rename
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        pressReturnKey()
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

// MARK: - Sort preference for the Copy actions

enum CopySortMode: String {
    case abc, descending, ascending
}

// MARK: - Output delivery (clipboard + optional TextEdit)

func deliverOutput(_ text: String, baseName: String) {
    // Always copy to the clipboard
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    guard UserDefaults.standard.bool(forKey: "openInTextEdit") else {
        NSSound(named: "Pop")?.play()
        return
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    let fileName = "\(baseName).\(formatter.string(from: Date())).txt"
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

    do {
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
        showErrorAlert(title: "Could Not Open TextEdit", message: error.localizedDescription)
        return
    }

    NSWorkspace.shared.open(
        [fileURL],
        withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
        configuration: NSWorkspace.OpenConfiguration(),
        completionHandler: nil
    )
}

func currentSortMode() -> CopySortMode {
    CopySortMode(rawValue: UserDefaults.standard.string(forKey: "copySortMode") ?? "") ?? .abc
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
