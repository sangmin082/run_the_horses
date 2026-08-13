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
    // 그리드는 VStack/HStack 균등 분할로 스스로 정확히 11×11을 이루고,
    // 말·선택·이동 표시는 오버레이에서 절대좌표(position)로 얹는다.
    // (GeometryReader 크기 계산이 어긋나 보드가 잘려 보이던 문제의 근본 수정)

    private var board: some View {
        VStack(spacing: 0) {
            ForEach(0..<GameEngine.boardSize, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<GameEngine.boardSize, id: \.self) { c in
                        cellBase(r * GameEngine.boardSize + c)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(dynamicLayer)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.bgRaised)
                .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
        )
    }

    private func cellBase(_ index: Int) -> some View {
        let terrain = GameEngine.terrain(at: index)
        let r = index / GameEngine.boardSize
        let c = index % GameEngine.boardSize
        let base: Color = switch terrain {
        case .oasis: Theme.oasisDeep
        case .meadow: Theme.meadow
        case .desert: (r + c) % 2 == 0 ? Theme.desert : Theme.desertAlt
        }
        return Rectangle()
            .fill(base)
            .overlay(Rectangle().stroke(Theme.cellLine, lineWidth: 0.5))
            .contentShape(Rectangle())
            .onTapGesture { viewModel.tapCell(index) }
    }

    /// index 칸의 중심 좌표
    private func center(of index: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(index % GameEngine.boardSize) + 0.5) * cell,
                y: (CGFloat(index / GameEngine.boardSize) + 0.5) * cell)
    }

    private var dynamicLayer: some View {
        GeometryReader { proxy in
            let cell = proxy.size.width / CGFloat(GameEngine.boardSize)
            ZStack {
                // 오아시스 파문 장식
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                        .frame(width: cell * 0.62, height: cell * 0.62)
                    Circle()
                        .fill(Theme.oasis)
                        .frame(width: cell * 0.34, height: cell * 0.34)
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: cell * 0.10, height: cell * 0.10)
                        .offset(x: -cell * 0.05, y: -cell * 0.07)
                }
                .position(center(of: GameEngine.center, cell: cell))

                // 마지막 수 표시
                if let last = viewModel.lastMove {
                    ForEach([last.from, last.to], id: \.self) { index in
                        Rectangle()
                            .fill(Theme.gold.opacity(0.16))
                            .frame(width: cell, height: cell)
                            .position(center(of: index, cell: cell))
                    }
                }

                // 선택한 말
                if let selection = viewModel.selection {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Theme.gold, lineWidth: 2.5)
                        .frame(width: cell - 3, height: cell - 3)
                        .position(center(of: selection, cell: cell))
                }

                // 이동 가능 칸 (● 슬라이드 / ◆ L자)
                ForEach(viewModel.targets, id: \.to) { move in
                    Group {
                        if move.kind == .slide {
                            Circle()
                                .fill(Color.black.opacity(0.42))
                                .frame(width: cell * 0.30, height: cell * 0.30)
                        } else {
                            Rectangle()
                                .fill(Color.black.opacity(0.42))
                                .frame(width: cell * 0.26, height: cell * 0.26)
                                .rotationEffect(.degrees(45))
                        }
                    }
                    .position(center(of: move.to, cell: cell))
                }

                // 말 토큰 — 고유 ID로 identity를 고정해 미끄러지는 이동 애니메이션
                ForEach(pieceList, id: \.id) { piece in
                    PieceToken(player: piece.player, size: cell * 0.82)
                        .position(center(of: piece.index, cell: cell))
                        .animation(.spring(duration: 0.3), value: piece.index)
                }
            }
        }
        .allowsHitTesting(false)
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
