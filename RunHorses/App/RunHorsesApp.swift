import SwiftUI

@main
struct RunHorsesApp: App {
    init() {
        // 지형·이동·승리 패턴·매치 흐름·AI를 JS 레퍼런스와 동일 시나리오로 검증 (DEBUG 전용)
        EngineSelfTest.run()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
