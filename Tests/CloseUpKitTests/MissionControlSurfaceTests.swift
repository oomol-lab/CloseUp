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

    @Test("exposeSurfacePresent is true only for a Dock-owned layer-18 window")
    func exposeSurface() {
        let withSurface = [
            window(pid: 10, layer: 0),
            window(pid: dockPID, layer: MissionControlSurface.exposeLayer), // the surface
        ]
        #expect(MissionControlSurface.exposeSurfacePresent(in: withSurface, dockPID: dockPID))

        // A layer-18 window owned by something OTHER than the Dock doesn't count.
        let foreignLayer18 = [window(pid: 99, layer: MissionControlSurface.exposeLayer)]
        #expect(!MissionControlSurface.exposeSurfacePresent(in: foreignLayer18, dockPID: dockPID))

        // The Dock at a different layer (MC closed) doesn't count.
        let dockOtherLayer = [window(pid: dockPID, layer: 0)]
        #expect(!MissionControlSurface.exposeSurfacePresent(in: dockOtherLayer, dockPID: dockPID))

        #expect(!MissionControlSurface.exposeSurfacePresent(in: [], dockPID: dockPID))
    }
}
