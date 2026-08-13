import SwiftUI

/// 대국 화면 — 11×11 보드, 라운드 점수, 안내 배너.
/// 1인용/온라인/튜토리얼/퍼즐 모두 이 화면을 사용한다.
struct GameView: View {
    @State var viewModel: GameViewModel
    /// 퍼즐 모드: "다음 퍼즐" 버튼이 눌리면 부모가 다음 퍼즐로 교체한다
    var onNextPuzzle: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showResignAlert = false

    private enum Palette {
        static let backgroundTop = Color(red: 0.13, green: 0.09, blue: 0.05)
        static let backgroundBottom = Color(red: 0.24, green: 0.15, blue: 0.07)
        static let desert = Color(red: 0.91, green: 0.81, blue: 0.53)
        static let desertAlt = Color(red: 0.87, green: 0.76, blue: 0.46)
        static let meadow = Color(red: 0.56, green: 0.70, blue: 0.42)
        static let oasis = Color(red: 0.23, green: 0.58, blue: 0.65)
        static let firstPiece = Color(red: 0.33, green: 0.20, blue: 0.11)
        static let secondPiece = Color(red: 0.96, green: 0.93, blue: 0.86)
        static let accent = Color(red: 1.0, green: 0.78, blue: 0.25)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.backgroundTop, Palette.backgroundBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                banner
                board
                Spacer(minLength: 0)
                bottomBar
            }
            .padding()

            if let overlay = viewModel.overlay {
                overlayView(overlay)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear { viewModel.cancelAllWork() }
        .alert("기권하시겠습니까?", isPresented: $showResignAlert) {
            Button("기권", role: .destructive) { viewModel.resign() }
            Button("계속하기", role: .cancel) {}
        }
        .alert("상대가 나갔습니다", isPresented: $viewModel.opponentLeft) {
            Button("나가기") { dismiss() }
        }
    }

    // MARK: 상단 — 점수/단계 표시

    @ViewBuilder
    private var header: some View {
        if viewModel.showsMatchScore {
            HStack(spacing: 12) {
                playerBadge(player: .first)
                VStack(spacing: 2) {
                    Text("\(min(viewModel.engine.roundNumber, GameEngine.totalRounds))라운드")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("3판 2선승")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.85))
                }
                playerBadge(player: .second)
            }
        } else if let step = viewModel.currentTutorialStep {
            Text("\(step.title)  (\(viewModel.tutorialStep + 1)/\(GameViewModel.tutorialSteps.count))")
                .font(.headline)
                .foregroundStyle(.white)
        } else if let puzzle = viewModel.currentPuzzle {
            Text(puzzle.title)
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    private func playerBadge(player: Player) -> some View {
        let isMe = player == viewModel.localPlayer
        let name = viewModel.isSolo || viewModel.currentPuzzle != nil
            ? (isMe ? "나" : viewModel.opponentName)
            : "\(player.label) 말"
        let active = viewModel.engine.turn == player && viewModel.engine.isRoundRunning
        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text(player.horseGlyph)
                Text(name).font(.caption.bold()).lineLimit(1)
            }
            HStack(spacing: 5) {
                ForEach(0..<GameEngine.winsNeeded, id: \.self) { i in
                    Circle()
                        .fill(i < viewModel.engine.roundWins[player.rawValue]
                              ? Palette.accent : .white.opacity(0.15))
                        .frame(width: 9, height: 9)
                }
            }
        }
        .foregroundStyle(active ? Palette.accent : .white.opacity(0.65))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(active ? 0.13 : 0.05))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? Palette.accent.opacity(0.7) : .clear, lineWidth: 1.5))
        )
    }

    private var banner: some View {
        Text(viewModel.banner)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.08)))
    }

    // MARK: 보드

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(GameEngine.boardSize)
            ZStack(alignment: .topLeading) {
                // 칸
                ForEach(0..<GameEngine.cellCount, id: \.self) { index in
                    cellView(index, size: cell)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(index % GameEngine.boardSize) * cell,
                                y: CGFloat(index / GameEngine.boardSize) * cell)
                        .onTapGesture { viewModel.tapCell(index) }
                }
                // 말 — 위치 변화에 스프링 애니메이션
                ForEach(pieceList, id: \.id) { piece in
                    Text(piece.player.horseGlyph)
                        .font(.system(size: cell * 0.62))
                        .foregroundStyle(piece.player == .first ? Palette.firstPiece : Palette.secondPiece)
                        .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(piece.index % GameEngine.boardSize) * cell,
                                y: CGFloat(piece.index / GameEngine.boardSize) * cell)
                        .allowsHitTesting(false)
                        .animation(.spring(duration: 0.3), value: piece.index)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .stroke(.black.opacity(0.35), lineWidth: 1.5))
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// 말 목록 — 뷰모델이 유지하는 말 고유 ID로 identity를 고정해
    /// 같은 말이 미끄러지는 이동 애니메이션이 되게 한다.
    private var pieceList: [(id: Int, index: Int, player: Player)] {
        viewModel.pieceIDs.compactMap { cell, id in
            guard let player = GameEngine.owner(of: viewModel.engine.board[cell]) else { return nil }
            return (id, cell, player)
        }
        .sorted { $0.id < $1.id }
    }

    @ViewBuilder
    private func cellView(_ index: Int, size: CGFloat) -> some View {
        let terrain = GameEngine.terrain(at: index)
        let r = index / GameEngine.boardSize
        let c = index % GameEngine.boardSize
        let base: Color = switch terrain {
        case .oasis: Palette.oasis
        case .meadow: Palette.meadow
        case .desert: (r + c) % 2 == 0 ? Palette.desert : Palette.desertAlt
        }
        let isTarget = viewModel.targets.contains { $0.to == index }
        let targetKind = viewModel.targets.first { $0.to == index }?.kind
        let isLastMove = viewModel.lastMove.map { $0.from == index || $0.to == index } ?? false

        ZStack {
            Rectangle().fill(base)
            if terrain == .oasis {
                Circle()
                    .fill(.white.opacity(0.35))
                    .frame(width: size * 0.35, height: size * 0.35)
                    .offset(y: -size * 0.08)
            }
            if isLastMove {
                Rectangle().fill(.black.opacity(0.16))
            }
            if viewModel.selection == index {
                Rectangle().stroke(Palette.accent, lineWidth: 2.5)
            }
            if isTarget {
                if targetKind == .slide {
                    Circle()
                        .fill(Palette.oasis.opacity(0.9))
                        .frame(width: size * 0.4, height: size * 0.4)
                } else {
                    Rectangle()
                        .fill(Palette.oasis.opacity(0.9))
                        .frame(width: size * 0.34, height: size * 0.34)
                        .rotationEffect(.degrees(45))
                }
            }
        }
        .overlay(Rectangle().stroke(.black.opacity(0.12), lineWidth: 0.5))
    }

    // MARK: 하단 바

    private var bottomBar: some View {
        HStack {
            if viewModel.showsMatchScore {
                Button {
                    showResignAlert = true
                } label: {
                    Label("기권", systemImage: "flag.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                Button {
                    dismiss()
                } label: {
                    Label("나가기", systemImage: "xmark")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
            if viewModel.isSolo {
                Button {
                    viewModel.undo()
                } label: {
                    Label("무르기", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                        .foregroundStyle(viewModel.canUndo ? Palette.accent : .white.opacity(0.3))
                }
                .disabled(!viewModel.canUndo)
            }
        }
    }

    // MARK: 오버레이

    @ViewBuilder
    private func overlayView(_ overlay: GameViewModel.Overlay) -> some View {
        let content: (title: String, subtitle: String, button: String, action: () -> Void, secondary: Bool)
        = switch overlay {
        case .roundWon(let mine, let round):
            (mine ? "🏁 \(round)라운드 승리!" : "😮 \(round)라운드 패배",
             "오아시스 도착! 라운드 점수 \(viewModel.engine.roundWins[0]) : \(viewModel.engine.roundWins[1])",
             "다음 라운드", { viewModel.startNextRound() }, false)
        case .matchWon(let mine):
            (mine ? "🏆 매치 승리!" : "💀 매치 패배",
             "최종 \(viewModel.engine.roundWins[0]) : \(viewModel.engine.roundWins[1])",
             "나가기", { dismiss() }, false)
        case .tutorialStepDone(let last):
            last ? ("🎓 튜토리얼 완료!", "이제 실전에서 만나요.", "완료", { dismiss() }, false)
                 : ("잘했어요!", "다음 단계로 넘어갑니다.", "다음 단계", { viewModel.advanceTutorial() }, false)
        case .tutorialRetry:
            ("다시 해볼까요?", "목표와 다르게 움직였어요.", "다시 시도", { viewModel.advanceTutorial() }, false)
        case .puzzleSolved(let last):
            last ? ("🎉 퍼즐 성공!", "모든 퍼즐을 풀었습니다!", "목록으로", { dismiss() }, false)
                 : ("🎉 퍼즐 성공!", "", onNextPuzzle != nil ? "다음 퍼즐" : "목록으로",
                    { if let onNextPuzzle { onNextPuzzle() } else { dismiss() } }, false)
        case .puzzleFailed(let reason):
            ("아쉬워요", reason, "다시 시도", { viewModel.retryPuzzle() }, true)
        }

        VStack(spacing: 16) {
            Text(content.title).font(.largeTitle.bold())
            if !content.subtitle.isEmpty {
                Text(content.subtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
            }
            Button(content.button, action: content.action)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .foregroundStyle(.black)
            if content.secondary {
                Button("나가기") { dismiss() }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 20).fill(.black.opacity(0.85)))
        .padding(40)
    }
}
