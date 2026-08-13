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
                LinearGradient(colors: [Color(red: 0.13, green: 0.09, blue: 0.05),
                                        Color(red: 0.27, green: 0.17, blue: 0.08)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack(spacing: 36) {
                    Spacer()

                    VStack(spacing: 10) {
                        Text("🐎")
                            .font(.system(size: 72))
                        Text("말달리자")
                            .font(.system(size: 46, weight: .black, design: .serif))
                            .foregroundStyle(.white)
                        Text("DEATH GAME — RUN THE HORSES")
                            .font(.caption.weight(.semibold))
                            .kerning(2)
                            .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.25).opacity(0.85))
                    }

                    VStack(spacing: 13) {
                        menuButton("혼자 하기", subtitle: "AI와 오아시스 경주 (난이도 4단계)", icon: "person.fill") {
                            showDifficultyDialog = true
                        }
                        menuButton("둘이 하기", subtitle: "방을 만들고 코드로 초대", icon: "person.2.fill") {
                            showOnlineLobby = true
                        }
                        menuButton("튜토리얼", subtitle: "3단계로 배우는 행마법", icon: "graduationcap.fill") {
                            tutorialGame = GameViewModel(mode: .tutorial)
                        }
                        menuButton("퍼즐", subtitle: "N수 안에 오아시스 도착", icon: "puzzlepiece.fill") {
                            showPuzzles = true
                        }
                        menuButton("전적", subtitle: "승패 기록 보기", icon: "chart.bar.fill") {
                            showStats = true
                        }
                        menuButton("게임 방법", subtitle: "규칙 읽기", icon: "book.fill") {
                            showRules = true
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer()

                    Text("정중앙 오아시스에 먼저 도착하면 승리 · 3판 2선승")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 8)
                }
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
            .sheet(isPresented: $showPuzzles) {
                PuzzlesView()
            }
            .sheet(isPresented: $showRules) {
                RulesView()
            }
            .sheet(isPresented: $showOnlineLobby) {
                OnlineLobbyView()
            }
            .sheet(isPresented: $showStats) {
                StatsView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func menuButton(_ title: String, subtitle: String, icon: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).opacity(0.6)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).opacity(0.5)
            }
            .foregroundStyle(.white)
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
        }
    }
}

extension GameViewModel: Identifiable {}

extension AIPlayer.Difficulty: Identifiable {
    var id: String { rawValue }
}

#Preview {
    HomeView()
}
