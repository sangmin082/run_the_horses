import SwiftUI

/// 게임 규칙 안내
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        section("목표",
                                "11×11 사막 한가운데의 오아시스에 자신의 말을 먼저 도착시키면 라운드 승리. 3라운드 중 2라운드를 이기면 매치에서 승리한다. 라운드마다 선공이 바뀐다.")
                        section("말과 배치",
                                "각자 말 10개로 시작한다. 말은 대각 방향으로 마주보는 두 코너에 5개씩 놓여 있다. 말이 잡히는 일은 없다.")
                        section("슬라이드 이동",
                                "가로 또는 세로 한 방향으로, 가장자리나 다른 말에 막히기 직전 칸까지 미끄러진다. 중간에 멈출 수 없다.")
                        section("L자 이동",
                                "체스의 나이트처럼 점프한다. 단, 도착 칸이 비어있는 사막 칸일 때만 가능하다 — 초록 초원 칸과 오아시스에는 L자로 들어갈 수 없다.")
                        section("오아시스 진입",
                                "오아시스에는 슬라이드로만 도착할 수 있다. 이동 방향 기준 오아시스 반대편 인접 칸에 말(내 말이든 상대 말이든)이 있어야 정확히 멈춘다. 중앙 라인을 선점하고 블로커를 만드는 것이 핵심 전략.")
                    }
                    .padding(24)
                }
            }
            .navigationTitle("게임 방법")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                DiamondMark(filled: true, size: 7)
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            Text(body)
                .font(.system(size: 14))
                .lineSpacing(5)
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
