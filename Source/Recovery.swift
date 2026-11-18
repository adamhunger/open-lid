import Foundation

protocol DisplayControl {
    func selectedMonitorIsActive(_ uuid: String) throws -> Bool
    func setInternal(enabled: Bool, requiring monitor: String?) throws
}

// Independent of AppKit, so failure handling can be tested without touching screens.
final class Recovery {
    let displays: DisplayControl
    var selectedMonitor: String?
    private(set) var automatic = false
    private(set) var restoring = false
    private(set) var detail = "Select your physical monitor, then enable automatic mode"
    private var failures = 0
    private var retryAt = Date.distantPast
    init(_ displays: DisplayControl) { self.displays = displays }

    func enable() {
        guard selectedMonitor != nil else { detail = "Select your physical monitor first"; return }
        automatic = true
        restoring = false
        failures = 0
        retryAt = .distantPast
        tick()
    }

    func restore() {
        // A manual restore always overrides automatic mode, including future wake events.
        automatic = false
        restoring = true
        failures = 0
        retryAt = .distantPast
        tick()
    }

    func tick(now: Date = Date()) {
        guard (automatic || restoring), now >= retryAt else { return }
        do {
            if restoring {
                try displays.setInternal(enabled: true, requiring: nil)
                restoring = false
                detail = "Built-in display restored; automatic mode off"
            } else {
                let present = try selectedMonitor.map { try displays.selectedMonitorIsActive($0) } ?? false
                try displays.setInternal(enabled: !present, requiring: selectedMonitor)
                detail = present ? "Using selected external monitor only" : "Selected monitor absent; built-in display restored"
            }
            failures = 0
            retryAt = .distantPast
        } catch {
            // Any configuration error enters recovery. Never abandon a failed restore.
            automatic = false
            restoring = true
            failures = min(failures + 1, 5)
            let delay = min(30.0, pow(2.0, Double(failures)))
            retryAt = now.addingTimeInterval(delay)
            detail = "Restoring: \(error). Retrying in \(Int(delay))s"
        }
    }
}
