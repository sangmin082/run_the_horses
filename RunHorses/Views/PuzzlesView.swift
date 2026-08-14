import SwiftUI

/// 퍼즐 목록 — 풀었던 퍼즐은 체크 표시. 선택하면 대국 화면으로 이동한다.
struct PuzzlesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var game: GameViewModel?
    @State private var currentIndex = 0

    private var stats: StatsStore { StatsStore.shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(Puzzles.all.enumerated()), id: \.element.id) { index, puzzle in
                        Button {
                            currentIndex = index
                            game = GameViewModel(mode: .puzzle(puzzle))
                        } label: {
                            HStack {
                                Text(puzzle.title)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(puzzle.ownMoves)수")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if stats.solvedPuzzles.contains(puzzle.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("정해진 수 안에 오아시스에 도착하면 성공! 상대는 최선을 다해 방어합니다.")
                }
            }
            .navigationTitle("퍼즐 \(stats.solvedPuzzles.count)/\(Puzzles.all.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .fullScreenCover(item: $game) { gameModel in
                GameView(viewModel: gameModel, onNextPuzzle: {
                    let next = currentIndex + 1
                    if next < Puzzles.all.count {
                        currentIndex = next
                        game = GameViewModel(mode: .puzzle(Puzzles.all[next]))
                    } else {
                        game = nil
                    }
                })
                .id(gameModel.id) // 퍼즐 교체 시 뷰 identity를 새 뷰모델에 묶는다
            }
        }
        .preferredColorScheme(.dark)
    }
}
