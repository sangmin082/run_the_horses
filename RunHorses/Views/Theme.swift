import SwiftUI

/// 말달리자 디자인 시스템 — "사막의 밤"
/// 짙은 밤모래 바탕 위에 모래빛 텍스트, 골드는 승리·활성 상태에만 아껴 쓴다.
/// 보드의 다이아몬드(초원)·원(오아시스) 모티프를 UI 전반의 장식 언어로 재사용한다.
enum Theme {
    // 바탕
    static let bg = Color(red: 0.094, green: 0.070, blue: 0.047)        // 밤모래
    static let bgRaised = Color(red: 0.141, green: 0.106, blue: 0.071)  // 패널
    static let hairline = Color(red: 0.95, green: 0.88, blue: 0.72).opacity(0.14)

    // 텍스트
    static let ink = Color(red: 0.95, green: 0.90, blue: 0.79)          // 본문
    static let inkFaint = Color(red: 0.95, green: 0.90, blue: 0.79).opacity(0.55)
    static let inkGhost = Color(red: 0.95, green: 0.90, blue: 0.79).opacity(0.32)

    // 액센트
    static let gold = Color(red: 0.93, green: 0.72, blue: 0.34)         // 승리·활성
    static let oasis = Color(red: 0.33, green: 0.63, blue: 0.67)        // 오아시스·이동 표시

    // 보드
    static let desert = Color(red: 0.851, green: 0.745, blue: 0.502)
    static let desertAlt = Color(red: 0.816, green: 0.702, blue: 0.443)
    static let meadow = Color(red: 0.478, green: 0.594, blue: 0.373)
    static let oasisDeep = Color(red: 0.196, green: 0.478, blue: 0.525)
    static let cellLine = Color.black.opacity(0.10)

    // 말
    static let bay = Color(red: 0.302, green: 0.188, blue: 0.110)       // 밤색 말
    static let bayHighlight = Color(red: 0.427, green: 0.278, blue: 0.169)
    static let ivory = Color(red: 0.965, green: 0.933, blue: 0.859)     // 흰 말
    static let ivoryShade = Color(red: 0.851, green: 0.800, blue: 0.702)
}

/// 다이아몬드(초원 모티프) — pips, 리스트 마커 등에 쓰는 작은 장식
struct DiamondMark: View {
    var filled: Bool
    var size: CGFloat = 9

    var body: some View {
        Rectangle()
            .fill(filled ? Theme.gold : .clear)
            .overlay(Rectangle().stroke(filled ? Theme.gold : Theme.inkGhost, lineWidth: 1.2))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(45))
    }
}

/// 말 토큰 — 보드와 UI 어디서나 같은 형태로 쓴다
struct PieceToken: View {
    let player: Player
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: player == .first
                            ? [Theme.bayHighlight, Theme.bay]
                            : [Theme.ivory, Theme.ivoryShade],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.7
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: size * 0.06, y: size * 0.06)
            Text("♞")
                .font(.system(size: size * 0.56))
                .foregroundStyle(player == .first ? Theme.ink.opacity(0.9) : Theme.bay)
                .offset(y: -size * 0.02)
        }
        .frame(width: size, height: size)
    }
}
