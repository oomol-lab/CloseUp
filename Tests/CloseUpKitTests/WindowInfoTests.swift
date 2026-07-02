import CoreGraphics
import Testing

@testable import CloseUpKit

@Suite("WindowInfo")
struct WindowInfoTests {
    private let mainDisplay = CGRect(x: 0, y: 0, width: 1728, height: 1117)

    private func entry(
        id: CGWindowID, pid: pid_t, owner: String, name: String,
        x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, layer: Int = 0
    ) -> [String: Any] {
        [
            kCGWindowNumber as String: id,
            kCGWindowOwnerPID as String: pid,
            kCGWindowOwnerName as String: owner,
            kCGWindowName as String: name,
            kCGWindowLayer as String: layer,
            kCGWindowBounds as String: ["X": x, "Y": y, "Width": w, "Height": h],
        ]
    }

    @Test("parses a well-formed CGWindowList entry")
    func parse() throws {
        let info = try #require(WindowInfo(cgEntry: entry(
            id: 42, pid: 99, owner: "Safari", name: "Apple", x: 10, y: 20, w: 300, h: 200
        )))
        #expect(info.windowID == 42)
        #expect(info.ownerPID == 99)
        #expect(info.ownerName == "Safari")
        #expect(info.frame == CGRect(x: 10, y: 20, width: 300, height: 200))
    }

    @Test("rejects an entry missing id/pid/bounds")
    func rejectIncomplete() {
        #expect(WindowInfo(cgEntry: [kCGWindowNumber as String: CGWindowID(1)]) == nil)
    }

    @Test("actionable keeps layer-0 app windows and drops Dock, off-layer, and degenerate windows")
    func actionableFiltering() {
        let entries: [[String: Any]] = [
            entry(id: 1, pid: 10, owner: "Safari", name: "A", x: 0, y: 0, w: 400, h: 300),
            entry(id: 2, pid: 11, owner: "Dock", name: "", x: 0, y: 0, w: 400, h: 300),       // Dock — drop
            entry(id: 3, pid: 12, owner: "Wallpaper", name: "", x: 0, y: 0, w: 1, h: 1),        // degenerate — drop
            entry(id: 4, pid: 13, owner: "Menu", name: "", x: 0, y: 0, w: 400, h: 24, layer: 25), // off-layer — drop
            entry(id: 5, pid: 14, owner: "Notes", name: "B", x: 50, y: 50, w: 500, h: 400),
        ]
        let actionable = [WindowInfo].actionable(from: entries)
        #expect(actionable.map(\.windowID) == [1, 5])
    }

    @Test("excludingPIDs drops a system owner regardless of its localized name")
    func excludeByPID() {
        // The field bug: kCGWindowOwnerName is localized, so the Dock arrives
        // as "程序坞" on a Chinese system and the name-based exclusion misses
        // it — its layer-0 surface then joins the hover candidates. The pid
        // exclusion must drop it no matter what the name says.
        let dockPID: pid_t = 77
        let entries = [
            entry(id: 1, pid: dockPID, owner: "程序坞", name: "", x: 0, y: 0, w: 800, h: 600),
            entry(id: 2, pid: 11, owner: "Safari", name: "A", x: 0, y: 0, w: 400, h: 300),
        ]
        #expect([WindowInfo].actionable(from: entries).map(\.windowID) == [1, 2]) // name filter misses
        #expect([WindowInfo].actionable(from: entries, excludingPIDs: [dockPID]).map(\.windowID) == [2])
    }

    @Test("CloseUp can exclude its own overlay owner")
    func excludeSelf() {
        let entries = [
            entry(id: 1, pid: 10, owner: "CloseUp", name: "", x: 0, y: 0, w: 100, h: 50),
            entry(id: 2, pid: 11, owner: "Safari", name: "A", x: 0, y: 0, w: 400, h: 300),
        ]
        let actionable = [WindowInfo].actionable(from: entries, excludingOwners: ["Dock", "CloseUp"])
        #expect(actionable.map(\.windowID) == [2])
    }

    @Test("frontmost returns the first window containing the point (front-to-back order)")
    func frontmost() {
        let front = WindowInfo(windowID: 1, ownerPID: 1, ownerName: "A", frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let back = WindowInfo(windowID: 2, ownerPID: 2, ownerName: "B", frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let windows = [front, back] // front-to-back
        #expect(windows.frontmost(containing: CGPoint(x: 50, y: 50))?.windowID == 1)
        #expect(windows.frontmost(containing: CGPoint(x: 300, y: 300))?.windowID == 2)
        #expect(windows.frontmost(containing: CGPoint(x: 500, y: 500)) == nil)
    }

    @Test("frontmost(topOverhang:) acquires a window from the straddle band above its top edge")
    func frontmostWithOverhang() {
        // CG coords: top edge is minY, "above" is smaller Y.
        let w = WindowInfo(windowID: 1, ownerPID: 1, ownerName: "A", frame: CGRect(x: 100, y: 200, width: 400, height: 300))
        let overhang: CGFloat = 16
        let aboveTop = CGPoint(x: 150, y: 200 - 8) // 8pt above the top edge, within the band
        // The raw frame misses it, but the overhang band acquires it.
        #expect([w].frontmost(containing: aboveTop) == nil)
        #expect([w].frontmost(containing: aboveTop, topOverhang: overhang)?.windowID == 1)
        // Inside the frame still works.
        #expect([w].frontmost(containing: CGPoint(x: 150, y: 250), topOverhang: overhang)?.windowID == 1)
        // Beyond the band (higher than overhang above the top) still misses.
        #expect([w].frontmost(containing: CGPoint(x: 150, y: 200 - 20), topOverhang: overhang) == nil)
    }

    @Test("anchoredOnScreen drops windows whose overlay anchor is off every display")
    func anchoredOnScreen() {
        let displays = [mainDisplay]
        let onScreen = WindowInfo(windowID: 1, ownerPID: 1, ownerName: "A", frame: CGRect(x: 100, y: 100, width: 400, height: 300))
        // A window the re-tile animation transiently reports off the left edge.
        let offScreen = WindowInfo(windowID: 2, ownerPID: 2, ownerName: "B", frame: CGRect(x: -260, y: 100, width: 400, height: 300))
        let kept = [offScreen, onScreen].anchoredOnScreen(displays: displays, inset: 8)
        #expect(kept.map(\.windowID) == [1])
    }

    @Test("anchoredOnScreen keeps everything when display list is unknown (empty)")
    func anchoredOnScreenEmptyDisplays() {
        let w = WindowInfo(windowID: 1, ownerPID: 1, ownerName: "A", frame: CGRect(x: -500, y: -500, width: 100, height: 100))
        #expect([w].anchoredOnScreen(displays: [], inset: 8).map(\.windowID) == [1])
    }

    @Test("anchoredOnScreen resolves the off-screen-shadow case to the real window underneath")
    func anchoredOnScreenUnshadows() {
        // Mirrors the field bug: a mis-reported window (id 9) sits in front and
        // covers the cursor but is anchored off-screen; the real window (id 3) is
        // behind it. After filtering, frontmost picks the real one.
        let displays = [mainDisplay]
        let ghost = WindowInfo(windowID: 9, ownerPID: 9, ownerName: "G", frame: CGRect(x: -260, y: 200, width: 900, height: 500))
        let real = WindowInfo(windowID: 3, ownerPID: 3, ownerName: "R", frame: CGRect(x: 120, y: 200, width: 600, height: 500))
        let point = CGPoint(x: 300, y: 400) // inside both frames
        #expect([ghost, real].frontmost(containing: point)?.windowID == 9)
        #expect([ghost, real].anchoredOnScreen(displays: displays, inset: 8).frontmost(containing: point)?.windowID == 3)
    }
}
