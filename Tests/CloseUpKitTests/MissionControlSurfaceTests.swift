import CoreGraphics
import Testing

@testable import CloseUpKit

@Suite("MissionControlSurface")
struct MissionControlSurfaceTests {
    private let dockPID: pid_t = 200

    private func window(pid: pid_t, layer: Int) -> [String: Any] {
        [
            kCGWindowOwnerPID as String: pid,
            kCGWindowLayer as String: layer,
        ]
    }

    private func window(
        pid: pid_t, layer: Int, owner: String, width: CGFloat, height: CGFloat
    ) -> [String: Any] {
        [
            kCGWindowOwnerPID as String: pid,
            kCGWindowLayer as String: layer,
            kCGWindowOwnerName as String: owner,
            kCGWindowBounds as String: ["X": CGFloat(0), "Y": CGFloat(0), "Width": width, "Height": height],
        ]
    }

    private let windowManagerPID: pid_t = 983

    @Test("exposeSurfacePresent (macOS ≤26 shape): true only for a Dock-owned layer-18 window")
    func exposeSurfaceDock() {
        let withSurface = [
            window(pid: 10, layer: 0),
            window(pid: dockPID, layer: MissionControlSurface.exposeLayer), // the surface
        ]
        #expect(MissionControlSurface.exposeSurfacePresent(
            in: withSurface, dockPID: dockPID, windowManagerPID: windowManagerPID))

        // A layer-18 window owned by something OTHER than the Dock doesn't count.
        let foreignLayer18 = [window(pid: 99, layer: MissionControlSurface.exposeLayer)]
        #expect(!MissionControlSurface.exposeSurfacePresent(
            in: foreignLayer18, dockPID: dockPID, windowManagerPID: windowManagerPID))

        // The Dock at a different layer (MC closed) doesn't count.
        let dockOtherLayer = [window(pid: dockPID, layer: 0)]
        #expect(!MissionControlSurface.exposeSurfacePresent(
            in: dockOtherLayer, dockPID: dockPID, windowManagerPID: windowManagerPID))

        #expect(!MissionControlSurface.exposeSurfacePresent(
            in: [], dockPID: dockPID, windowManagerPID: windowManagerPID))
    }

    @Test("exposeSurfacePresent (macOS 27 shape): true for a WindowManager-owned layer-19 window")
    func exposeSurfaceWindowManager() {
        // The verified Golden Gate landscape: Dock only at layer 20, WindowManager
        // at 19 (the surface) plus its MC auxiliaries — 19 alone must open.
        let goldenGate = [
            window(pid: dockPID, layer: 20),
            window(pid: windowManagerPID, layer: MissionControlSurface.windowManagerExposeLayer),
            window(pid: windowManagerPID, layer: 14),
            window(pid: windowManagerPID, layer: 0),
        ]
        #expect(MissionControlSurface.exposeSurfacePresent(
            in: goldenGate, dockPID: dockPID, windowManagerPID: windowManagerPID))

        // WindowManager idle (MC closed) owns no layer-19 window → no session.
        let idle = [window(pid: dockPID, layer: 20), window(pid: windowManagerPID, layer: 0)]
        #expect(!MissionControlSurface.exposeSurfacePresent(
            in: idle, dockPID: dockPID, windowManagerPID: windowManagerPID))

        // The generations don't cross-match: Dock@19 / WindowManager@18 are not surfaces.
        let crossed = [
            window(pid: dockPID, layer: MissionControlSurface.windowManagerExposeLayer),
            window(pid: windowManagerPID, layer: MissionControlSurface.exposeLayer),
        ]
        #expect(!MissionControlSurface.exposeSurfacePresent(
            in: crossed, dockPID: dockPID, windowManagerPID: windowManagerPID))
    }

    @Test("either pid may be absent — the other signal still opens, and no pids means no session")
    func exposeSurfaceMissingPIDs() {
        let dockSurface = [window(pid: dockPID, layer: MissionControlSurface.exposeLayer)]
        let wmSurface = [window(pid: windowManagerPID, layer: MissionControlSurface.windowManagerExposeLayer)]
        #expect(MissionControlSurface.exposeSurfacePresent(
            in: dockSurface, dockPID: dockPID, windowManagerPID: nil))
        #expect(MissionControlSurface.exposeSurfacePresent(
            in: wmSurface, dockPID: nil, windowManagerPID: windowManagerPID))
        #expect(!MissionControlSurface.exposeSurfacePresent(
            in: dockSurface + wmSurface, dockPID: nil, windowManagerPID: nil))
    }

    @Test("layerDiagnostic summarizes non-zero layers, layer-descending, keeping the largest size per group")
    func layerDiagnosticSummary() {
        let dump = MissionControlSurface.layerDiagnostic(in: [
            window(pid: 10, layer: 0, owner: "Safari", width: 800, height: 600), // layer 0 → noise, dropped
            window(pid: dockPID, layer: 18, owner: "程序坞", width: 1728, height: 1117),
            window(pid: dockPID, layer: 18, owner: "程序坞", width: 3360, height: 1890), // same group, larger → representative
            window(pid: 300, layer: 1000, owner: "CloseUp", width: 86, height: 34),
            window(pid: dockPID, layer: 20, owner: "程序坞", width: 1728, height: 1117),
        ])
        #expect(dump == "CloseUp(300)@1000:86x34 程序坞(200)@20:1728x1117 程序坞(200)@18:3360x1890×2")
    }

    @Test("layerDiagnostic handles missing fields and an all-layer-0 dump")
    func layerDiagnosticEdges() {
        // Only layer-0 windows → nothing to report, but never an empty string.
        let quiet = MissionControlSurface.layerDiagnostic(in: [window(pid: 10, layer: 0)])
        #expect(quiet == "(no non-zero-layer windows)")

        // A non-zero-layer entry with no owner/bounds still shows up, degraded.
        let bare = MissionControlSurface.layerDiagnostic(in: [window(pid: 10, layer: 25)])
        #expect(bare == "?(10)@25")
    }

    @Test("layerDiagnostic caps the group count and reports the overflow")
    func layerDiagnosticOverflow() {
        let many = (1...35).map { window(pid: pid_t($0), layer: $0, owner: "App\($0)", width: 100, height: 100) }
        let dump = MissionControlSurface.layerDiagnostic(in: many, maxGroups: 30)
        #expect(dump.hasSuffix(" +5 more"))
        #expect(dump.contains("App35(35)@35:100x100")) // highest layer leads
        #expect(!dump.contains("App5(5)@5:")) // the 5 lowest layers are the ones capped
    }
}
