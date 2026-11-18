import Foundation

final class FakeDisplays: DisplayControl {
    var active = Set(["physical", "virtual"])
    var failRestore = false
    var failDisable = false
    var enabled = true
    var calls: [Bool] = []
    struct Failure: Error {}
    func selectedMonitorIsActive(_ uuid: String) throws -> Bool { active.contains(uuid) }
    func setInternal(enabled: Bool, requiring monitor: String?) throws {
        calls.append(enabled)
        if enabled ? failRestore : failDisable { throw Failure() }
        self.enabled = enabled
    }
}

@main struct Tests {
    static func main() {
        let d = FakeDisplays()
        let r = Recovery(d)
        r.enable()
        assert(!r.automatic && d.calls.isEmpty, "Must select a monitor before disabling")
        r.selectedMonitor = "physical"
        r.enable()
        assert(r.automatic && !d.enabled)
        r.restore()
        r.tick(now: Date().addingTimeInterval(60))
        assert(d.enabled && !r.automatic, "Manual recovery must survive later polling/wake")
        r.enable()
        d.active.remove("physical")
        r.tick()
        assert(d.enabled, "An unrelated virtual display must not keep the internal screen off")
        d.active.insert("physical")
        r.enable()
        d.failRestore = true
        r.restore()
        assert(r.restoring && !r.automatic)
        let attempts = d.calls.count
        r.tick()
        assert(d.calls.count == attempts, "Backoff must prevent busy retrying")
        let future = Date().addingTimeInterval(60)
        r.tick(now: future)
        assert(d.calls.count == attempts + 1 && r.restoring)
        d.failRestore = false
        r.tick(now: future.addingTimeInterval(60))
        assert(d.enabled && !r.restoring)
        d.failDisable = true
        r.enable()
        assert(!r.automatic && r.restoring, "Disable errors must enter recovery")
        r.tick(now: Date().addingTimeInterval(120))
        assert(d.enabled && !r.restoring)
        print("PASS: monitor selection, manual override, virtual-display isolation, restore retries, backoff, disable-failure recovery")
    }
}
