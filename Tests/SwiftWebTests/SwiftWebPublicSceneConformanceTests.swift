import SwiftWeb
import Testing

@Suite
struct SwiftWebPublicSceneConformanceTests {
    @Test
    func applicationSceneConformsThroughItsBody() {
        let scene = PublicCompositeScene()

        #expect(type(of: scene) == PublicCompositeScene.self)
    }
}

private struct PublicCompositeScene: Scene {
    var body: some Scene {
        Endpoint("/public-scene") { _ in
            Response(status: .ok)
        }
    }
}
