import AppKit
import CoreGraphics
import Darwin
import Carbon

// Resolved at runtime so an unavailable private API fails without changing displays.
typealias Configure = @convention(c) (CGDisplayConfigRef, UInt32, Bool) -> Int32
typealias DisplayList = @convention(c) (UInt32, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>) -> Int32

struct DisplayFailure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}

final class Displays: DisplayControl {
    let handle: UnsafeMutableRawPointer
    let configure: Configure
    let fullList: DisplayList

    init() throws {
        guard let h = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY),
              let c = dlsym(h, "SLSConfigureDisplayEnabled"),
              let l = dlsym(h, "SLSGetDisplayList") else {
            throw DisplayFailure("This macOS version does not expose the required display controls.")
        }
        handle = h
        configure = unsafeBitCast(c, to: Configure.self)
        fullList = unsafeBitCast(l, to: DisplayList.self)
    }

    func list(all: Bool = false) throws -> [UInt32] {
        var ids = [UInt32](repeating: 0, count: 64)
        var count: UInt32 = 0
        let result = all ? fullList(64, &ids, &count) : CGGetActiveDisplayList(64, &ids, &count).rawValue
        guard result == 0, count <= 64 else { throw DisplayFailure("Could not enumerate displays (\(result)).") }
        return Array(ids.prefix(Int(count)))
    }

    func uuid(_ id: UInt32) -> String? {
        guard let value = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, value) as String
    }
    func selectedMonitorIsActive(_ uuid: String) throws -> Bool {
        try list().contains { CGDisplayIsBuiltin($0) == 0 && self.uuid($0) == uuid }
    }
    func setInternal(enabled: Bool, requiring monitor: String? = nil) throws {
        if !enabled {
            guard let monitor, try selectedMonitorIsActive(monitor) else {
                throw DisplayFailure("The selected physical monitor must be active.")
            }
        }
        guard let id = try list(all: true).first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            throw DisplayFailure("The built-in display could not be found.")
        }
        // Online includes mirrored displays; active alone does not.
        if (CGDisplayIsOnline(id) != 0) == enabled { return }
        var transaction: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&transaction)
        guard begin == .success, let transaction else { throw DisplayFailure("Could not begin display change.") }
        let result = configure(transaction, id, enabled)
        guard result == 0 else {
            CGCancelDisplayConfiguration(transaction)
            throw DisplayFailure("Display change failed (\(result)).")
        }
        // Process-scoped: macOS is asked to restore the configuration if this process exits.
        let commit = CGCompleteDisplayConfiguration(transaction, .forAppOnly)
        guard commit == .success else { throw DisplayFailure("Could not commit display change (\(commit.rawValue)).") }
        guard (CGDisplayIsOnline(id) != 0) == enabled else {
            throw DisplayFailure("Display change has not yet been confirmed.")
        }
    }

    func status() throws -> String {
        let active = try list()
        return try list(all: true).map {
            "\($0): \(CGDisplayIsBuiltin($0) != 0 ? "built-in" : "external"), \(active.contains($0) ? "active" : "inactive")"
        }.joined(separator: "\n")
    }
}

final class RestoreHotKey {
    static let signature: OSType = 0x4F4C4944
    var key: EventHotKeyRef?
    var handler: EventHandlerRef?
    let action: () -> Void
    init(action: @escaping () -> Void) throws {
        self.action = action
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == RestoreHotKey.signature, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            Unmanaged<RestoreHotKey>.fromOpaque(context).takeUnretainedValue().action()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard installed == noErr else { throw DisplayFailure("Could not install restore shortcut (\(installed)).") }
        let registered = RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(controlKey | optionKey | cmdKey), EventHotKeyID(signature: Self.signature, id: 1), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &key)
        guard registered == noErr else {
            if let handler { RemoveEventHandler(handler); self.handler = nil }
            throw DisplayFailure("Restore shortcut is unavailable or already in use (\(registered)).")
        }
    }
    deinit {
        if let key { UnregisterEventHotKey(key) }
        if let handler { RemoveEventHandler(handler) }
    }
}

final class Controller: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let displays: Displays
    let recovery: Recovery
    var item: NSStatusItem!
    var timer: Timer?
    var hotKey: RestoreHotKey?
    var shortcutError: String?
    var sleeping = false
    var quitWhenRestored = false
    init(_ displays: Displays) {
        self.displays = displays
        recovery = Recovery(displays)
        recovery.selectedMonitor = UserDefaults.standard.string(forKey: "selectedPhysicalMonitor")
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "▣"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        do { hotKey = try RestoreHotKey { [weak self] in self?.restore() } }
        catch { shortcutError = String(describing: error) }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.reconcile() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        updateMenu(menu)
    }
    @objc func willSleep() { sleeping = true }
    @objc func didWake() { sleeping = false; reconcile() }
    @objc func toggle() {
        guard hotKey != nil else { return }
        if recovery.automatic { restore() } else { recovery.enable() }
    }
    @objc func selectMonitor(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        recovery.restore()
        recovery.selectedMonitor = uuid
        UserDefaults.standard.set(uuid, forKey: "selectedPhysicalMonitor")
    }
    func reconcile() {
        guard !sleeping else { return }
        recovery.tick()
        if quitWhenRestored && !recovery.restoring { NSApp.terminate(nil) }
    }
    @objc func restore() {
        quitWhenRestored = false
        recovery.restore()
    }
    @objc func quit() {
        recovery.restore()
        quitWhenRestored = true
        if !recovery.restoring { NSApp.terminate(nil) }
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        hotKey = nil
        try? displays.setInternal(enabled: true)
    }
    func menuWillOpen(_ menu: NSMenu) { updateMenu(menu) }
    func updateMenu(_ menu: NSMenu) {
        // Rebuild only before tracking starts; recovery never mutates a tracked menu.
        menu.removeAllItems()
        menu.addItem(withTitle: "Open Lid", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: recovery.detail, action: nil, keyEquivalent: "")
        menu.addItem(withTitle: shortcutError ?? "Restore anytime: ⌃⌥⌘R", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        let choose = NSMenuItem(title: "Select your physical monitor", action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for screen in NSScreen.screens {
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                  CGDisplayIsBuiltin(id) == 0, let uuid = displays.uuid(id) else { continue }
            let entry = choices.addItem(withTitle: screen.localizedName, action: #selector(selectMonitor(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = uuid
            entry.state = recovery.selectedMonitor == uuid ? .on : .off
        }
        choose.submenu = choices
        menu.addItem(choose)
        menu.autoenablesItems = false
        let toggle = menu.addItem(withTitle: "External display only (automatic)", action: #selector(toggle), keyEquivalent: "")
        toggle.state = recovery.automatic ? .on : .off
        toggle.isEnabled = hotKey != nil && recovery.selectedMonitor != nil
        toggle.target = self
        let restore = menu.addItem(withTitle: "Restore built-in display — ⌃⌥⌘R", action: #selector(restore), keyEquivalent: "")
        restore.target = self
        let quit = menu.addItem(withTitle: "Restore and quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
    }
}

do {
    let displays = try Displays()
    if CommandLine.arguments.contains("--status") {
        print(try displays.status())
    } else if CommandLine.arguments.contains("--check-hotkey") {
        let key = try RestoreHotKey { }
        withExtendedLifetime(key) { print("Control–Option–Command–R registered successfully; releasing it now.") }
    } else {
        let app = NSApplication.shared
        let controller = Controller(displays)
        app.delegate = controller
        withExtendedLifetime(controller) { app.run() }
    }
} catch {
    fputs("Open Lid: \(error)\n", stderr)
    exit(1)
}
