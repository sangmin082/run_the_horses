import SwiftUI

struct HomeView: View {
    @State private var showDifficultyDialog = false
    @State private var soloGame: GameViewModel?
    @State private var tutorialGame: GameViewModel?
    @State private var showPuzzles = false
    @State private var showRules = false
    @State private var showOnlineLobby = false
    @State private var showStats = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                backdrop

                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 24)
                    wordmark
                    Spacer(minLength: 24)
                    menu
                    Spacer(minLength: 20)
                    footer
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 12)
            }
            .confirmationDialog("AI 난이도", isPresented: $showDifficultyDialog, titleVisibility: .visible) {
                ForEach(AIPlayer.Difficulty.allCases) { difficulty in
                    Button(difficulty.label) {
                        soloGame = GameViewModel(mode: .solo(difficulty))
                    }
                }
            }
            .fullScreenCover(item: $soloGame) { game in
                GameView(viewModel: game)
            }
            .fullScreenCover(item: $tutorialGame) { game in
                GameView(viewModel: game)
            }
            .sheet(isPresented: $showPuzzles) { PuzzlesView() }
            .sheet(isPresented: $showRules) { RulesView() }
            .sheet(isPresented: $showOnlineLobby) { OnlineLobbyView() }
            .sheet(isPresented: $showStats) { StatsView() }
        }
        .tint(Theme.gold)
        .preferredColorScheme(.dark)
    }

    // MARK: 배경 장식 — 오아시스 동심원과 커다란 말 실루엣

    private var backdrop: some View {
        GeometryReader { proxy in
            ZStack {
                // 우상단: 오아시스 파문
                ZStack {
                    ForEach(0..<3, id: \.self) { ring in
                        Circle()
                            .stroke(Theme.oasis.opacity(0.16 - Double(ring) * 0.04),
                                    lineWidth: 1.5)
                            .frame(width: 140 + CGFloat(ring) * 90)
                    }
                    Circle()
                        .fill(Theme.oasis.opacity(0.18))
                        .frame(width: 54)
                }
                .position(x: proxy.size.width - 40, y: 110)

                // 좌하단: 밤에 잠긴 말 실루엣
                Text("♞")
                    .font(.system(size: 460))
                    .foregroundStyle(Color.black.opacity(0.35))
                    .rotationEffect(.degrees(-8))
                    .position(x: 90, y: proxy.size.height - 130)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: 워드마크

    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                DiamondMark(filled: true, size: 7)
                Text("DEATH GAME ORIGINAL")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(3)
                    .foregroundStyle(Theme.inkFaint)
            }

            Text("말달리자")
                .font(.system(size: 58, weight: .black))
                .kerning(-1)
                .foregroundStyle(Theme.ink)

            Rectangle()
                .fill(Theme.gold)
                .frame(width: 44, height: 3)

            Text("사막을 가로질러, 정중앙의 오아시스에\n먼저 도착하는 말이 승리한다.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(Theme.inkFaint)
        }
    }

    // MARK: 메뉴 — 주 액션 하나만 강조하고 나머지는 조용하게

    private var menu: some View {
        VStack(spacing: 12) {
            Button {
                showDifficultyDialog = true
            } label: {
                HStack {
                    Text("혼자 하기")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Text("AI 난이도 4단계")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.7)
                }
                .foregroundStyle(Theme.bg)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.gold))
            }

            Button {
                showOnlineLobby = true
            } label: {
                HStack {
                    Text("둘이 하기")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Text("방 코드로 초대")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkFaint)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.bgRaised)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.hairline, lineWidth: 1))
                )
            }

            HStack(spacing: 12) {
                quietTile("튜토리얼") { tutorialGame = GameViewModel(mode: .tutorial) }
                quietTile("퍼즐") { showPuzzles = true }
            }
            HStack(spacing: 12) {
                quietTile("전적") { showStats = true }
                quietTile("게임 방법") { showRules = true }
            }
        }
    }

    private func quietTile(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                DiamondMark(filled: true, size: 6)
                DiamondMark(filled: true, size: 6)
                DiamondMark(filled: false, size: 6)
            }
            Text("3판 2선승 · 라운드마다 선공 교대")
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkGhost)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

extension GameViewModel: Identifiable {}

extension AIPlayer.Difficulty: Identifiable {
    var id: String { rawValue }
}

#Preview {
    HomeView()
}
