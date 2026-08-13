import SwiftUI

/// 대국 화면 — 11×11 보드, 라운드 점수, 안내.
/// 1인용/온라인/튜토리얼/퍼즐 모두 이 화면을 사용한다.
struct GameView: View {
    @State var viewModel: GameViewModel
    /// 퍼즐 모드: "다음 퍼즐" 버튼이 눌리면 부모가 다음 퍼즐로 교체한다
    var onNextPuzzle: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showResignAlert = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                banner
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                board
                    .padding(.horizontal, 14)
                Spacer(minLength: 0)
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 6)
            }

            if viewModel.overlay != nil {
                overlayView
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

    // MARK: 상단 — 스코어보드 (박스 없이 타이포그래피로)

    @ViewBuilder
    private var header: some View {
        if viewModel.showsMatchScore {
            HStack(alignment: .center) {
                sideColumn(player: .first, alignment: .leading)
                Spacer()
                VStack(spacing: 3) {
                    Text("\(min(viewModel.engine.roundNumber, GameEngine.totalRounds))")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(Theme.ink)
                    Text("라운드")
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Theme.inkGhost)
                }
                Spacer()
                sideColumn(player: .second, alignment: .trailing)
            }
        } else if let step = viewModel.currentTutorialStep {
            titleHeader(step.title,
                        detail: "\(viewModel.tutorialStep + 1) / \(GameViewModel.tutorialSteps.count)")
        } else if let puzzle = viewModel.currentPuzzle {
            titleHeader(puzzle.title, detail: "\(puzzle.ownMoves)수 퍼즐")
        }
    }

    private func titleHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            Spacer()
        }
    }

    private func sideColumn(player: Player, alignment: HorizontalAlignment) -> some View {
        let isMe = player == viewModel.localPlayer
        let name = viewModel.isSolo ? (isMe ? "나" : "AI") : "\(player.label) 말"
        let active = viewModel.engine.turn == player && viewModel.engine.isRoundRunning
        return VStack(alignment: alignment, spacing: 7) {
            HStack(spacing: 8) {
                if alignment == .leading {
                    PieceToken(player: player, size: 26)
                    Text(name)
                        .font(.system(size: 14, weight: active ? .bold : .medium))
                        .foregroundStyle(active ? Theme.ink : Theme.inkFaint)
                } else {
                    Text(name)
                        .font(.system(size: 14, weight: active ? .bold : .medium))
                        .foregroundStyle(active ? Theme.ink : Theme.inkFaint)
                    PieceToken(player: player, size: 26)
                }
            }
            HStack(spacing: 7) {
                ForEach(0..<GameEngine.winsNeeded, id: \.self) { i in
                    DiamondMark(filled: i < viewModel.engine.roundWins[player.rawValue], size: 8)
                }
                if active {
                    Circle()
                        .fill(Theme.gold)
                        .frame(width: 5, height: 5)
                        .padding(.leading, 2)
                }
            }
        }
    }

    private var banner: some View {
        Text(viewModel.banner)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, minHeight: 40)
    }

    // MARK: 보드

    private var board: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(GameEngine.boardSize)
            ZStack(alignment: .topLeading) {
                ForEach(0..<GameEngine.cellCount, id: \.self) { index in
                    cellView(index, size: cell)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(index % GameEngine.boardSize) * cell,
                                y: CGFloat(index / GameEngine.boardSize) * cell)
                        .onTapGesture { viewModel.tapCell(index) }
                }
                ForEach(pieceList, id: \.id) { piece in
                    PieceToken(player: piece.player, size: cell * 0.82)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(piece.index % GameEngine.boardSize) * cell,
                                y: CGFloat(piece.index / GameEngine.boardSize) * cell)
                        .allowsHitTesting(false)
                        .animation(.spring(duration: 0.3), value: piece.index)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.bgRaised)
                    .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
            )
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1.06, contentMode: .fit)
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
        case .oasis: Theme.oasisDeep
        case .meadow: Theme.meadow
        case .desert: (r + c) % 2 == 0 ? Theme.desert : Theme.desertAlt
        }
        let targetKind = viewModel.targets.first { $0.to == index }?.kind
        let isLastMove = viewModel.lastMove.map { $0.from == index || $0.to == index } ?? false

        ZStack {
            Rectangle().fill(base)

            if terrain == .oasis {
                // 오아시스: 잔잔한 파문
                Circle()
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
                    .frame(width: size * 0.62, height: size * 0.62)
                Circle()
                    .fill(Theme.oasis)
                    .frame(width: size * 0.34, height: size * 0.34)
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: size * 0.10, height: size * 0.10)
                    .offset(x: -size * 0.05, y: -size * 0.07)
            }
            if isLastMove {
                Rectangle().fill(Theme.gold.opacity(0.16))
            }
            if viewModel.selection == index {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Theme.gold, lineWidth: 2.5)
                    .padding(1)
            }
            if let targetKind {
                if targetKind == .slide {
                    Circle()
                        .fill(Color.black.opacity(0.42))
                        .frame(width: size * 0.30, height: size * 0.30)
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.42))
                        .frame(width: size * 0.26, height: size * 0.26)
                        .rotationEffect(.degrees(45))
                }
            }
        }
        .overlay(Rectangle().stroke(Theme.cellLine, lineWidth: 0.5))
    }

    // MARK: 하단 바

    private var bottomBar: some View {
        HStack {
            if viewModel.showsMatchScore {
                quietButton("기권") { showResignAlert = true }
            } else {
                quietButton("나가기") { dismiss() }
            }
            Spacer()
            if viewModel.isSolo {
                Button {
                    viewModel.undo()
                } label: {
                    Text("무르기")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.canUndo ? Theme.ink : Theme.inkGhost)
                }
                .disabled(!viewModel.canUndo)
            }
        }
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    private func quietButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    // MARK: 오버레이

    private struct OverlayContent {
        var headline: String
        var accent: Bool = false        // 골드 강조 (승리)
        var subtitle = ""
        var button: String
        var action: () -> Void
        var secondaryButton: String?
        var secondaryAction: (() -> Void)?
    }

    private var overlayContent: OverlayContent? {
        guard let overlay = viewModel.overlay else { return nil }
        let wins = viewModel.engine.roundWins
        switch overlay {
        case .roundWon(let mine, let round):
            return OverlayContent(
                headline: mine ? "\(round)라운드 승리" : "\(round)라운드 패배",
                accent: mine,
                subtitle: "오아시스 도착 — 라운드 점수 \(wins[0]) : \(wins[1])",
                button: "다음 라운드",
                action: { viewModel.startNextRound() }
            )
        case .matchWon(let mine):
            return OverlayContent(
                headline: mine ? "승리" : "패배",
                accent: mine,
                subtitle: "최종 라운드 점수 \(wins[0]) : \(wins[1])",
                button: "나가기",
                action: { dismiss() }
            )
        case .tutorialStepDone(let last):
            if last {
                return OverlayContent(
                    headline: "튜토리얼 완료",
                    accent: true,
                    subtitle: "행마법을 모두 익혔습니다. 이제 실전에서 만나요.",
                    button: "완료",
                    action: { dismiss() }
                )
            }
            return OverlayContent(
                headline: "잘했어요",
                accent: true,
                subtitle: "다음 단계로 넘어갑니다.",
                button: "다음 단계",
                action: { viewModel.advanceTutorial() }
            )
        case .tutorialRetry:
            return OverlayContent(
                headline: "다시 해볼까요?",
                subtitle: "목표와 다르게 움직였어요.",
                button: "다시 시도",
                action: { viewModel.advanceTutorial() }
            )
        case .puzzleSolved(let last):
            if last {
                return OverlayContent(
                    headline: "퍼즐 성공",
                    accent: true,
                    subtitle: "모든 퍼즐을 풀었습니다.",
                    button: "목록으로",
                    action: { dismiss() }
                )
            }
            return OverlayContent(
                headline: "퍼즐 성공",
                accent: true,
                button: onNextPuzzle != nil ? "다음 퍼즐" : "목록으로",
                action: { [onNextPuzzle] in
                    if let onNextPuzzle { onNextPuzzle() } else { dismiss() }
                }
            )
        case .puzzleFailed(let reason):
            return OverlayContent(
                headline: "아쉬워요",
                subtitle: reason,
                button: "다시 시도",
                action: { viewModel.retryPuzzle() },
                secondaryButton: "나가기",
                secondaryAction: { dismiss() }
            )
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        if let content = overlayContent {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(content.accent ? Theme.gold : Theme.hairline)
                        .frame(width: 44, height: 3)
                        .padding(.bottom, 18)

                    Text(content.headline)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Theme.ink)

                    if !content.subtitle.isEmpty {
                        Text(content.subtitle)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.top, 10)
                    }

                    Button(action: content.action) {
                        Text(content.button)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.bg)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.gold))
                    }
                    .padding(.top, 24)

                    if let secondary = content.secondaryButton,
                       let secondaryAction = content.secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondary)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .padding(.top, 14)
                    }
                }
                .padding(28)
                .frame(maxWidth: 320)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Theme.bgRaised)
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.hairline, lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
                )
            }
        }
    }
}
