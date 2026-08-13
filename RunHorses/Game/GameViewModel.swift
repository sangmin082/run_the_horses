import Foundation
import Observation

/// 한 판의 대국을 진행하는 뷰모델.
/// 1인용은 AI가 상대 무브를 만들고, 온라인은 RoomClient가 상대 무브를 전달한다.
/// 튜토리얼·퍼즐은 커스텀 포지션에서 시작한다. 모두 동일한 `GameEngine`으로 상태가 결정된다.
@Observable
@MainActor
final class GameViewModel {
    enum Mode {
        case solo(AIPlayer.Difficulty)
        case online(RoomClient)
        case tutorial
        case puzzle(Puzzle)
    }

    struct TutorialStep {
        let title: String
        let text: String
        let pieces: [(String, Player)]
        let isSatisfied: (Move) -> Bool
    }

    static let tutorialSteps: [TutorialStep] = [
        TutorialStep(
            title: "1단계 · 슬라이드",
            text: "말은 가장자리나 다른 말에 막히기 직전까지 미끄러집니다(중간 정지 불가). k6의 말을 위로 끝까지 — a6까지 — 보내보세요.",
            pieces: [("k6", .first)],
            isSatisfied: { GameEngine.cellName($0.from) == "k6" && GameEngine.cellName($0.to) == "a6" }
        ),
        TutorialStep(
            title: "2단계 · L자 이동",
            text: "나이트처럼 점프하되 비어있는 사막 칸에만 도착할 수 있어요. 초록 초원 칸으로는 L자 이동이 안 됩니다. d5의 말로 L자 이동을 해보세요.",
            pieces: [("d5", .first)],
            isSatisfied: { $0.kind == .lshape }
        ),
        TutorialStep(
            title: "3단계 · 오아시스 진입",
            text: "오아시스엔 슬라이드로만 도착할 수 있고, 반대편 인접 칸에 블로커가 있어야 정확히 멈춥니다. e6의 블로커를 이용해 k6의 말을 f6에 세워보세요.",
            pieces: [("k6", .first), ("e6", .second)],
            isSatisfied: { $0.to == GameEngine.center }
        ),
    ]

    /// 라운드/매치 종료 또는 튜토리얼·퍼즐 판정 결과 오버레이
    enum Overlay: Equatable {
        case roundWon(mine: Bool, round: Int)
        case matchWon(mine: Bool)
        case tutorialStepDone(last: Bool)
        case tutorialRetry
        case puzzleSolved(last: Bool)
        case puzzleFailed(reason: String)
    }

    let mode: Mode
    private(set) var engine: GameEngine
    private(set) var localPlayer: Player
    private(set) var selection: Int?
    private(set) var targets: [Move] = []
    private(set) var lastMove: Move?
    private(set) var banner = ""
    private(set) var overlay: Overlay?
    private(set) var tutorialStep = 0
    private(set) var puzzleMovesUsed = 0
    /// 칸 → 말 고유 ID (이동 애니메이션이 같은 말을 추적하도록)
    private(set) var pieceIDs: [Int: Int] = [:]
    private var nextPieceID = 0
    var opponentLeft = false
    private var statsRecorded = false
    private var aiTask: Task<Void, Never>?

    var isMyTurn: Bool { engine.turn == localPlayer && engine.isRoundRunning }
    var isSolo: Bool { if case .solo = mode { return true }; return false }
    var isTutorial: Bool { if case .tutorial = mode { return true }; return false }
    var isPuzzle: Bool { if case .puzzle = mode { return true }; return false }
    var showsMatchScore: Bool { !isTutorial && !isPuzzle }
    var canUndo: Bool {
        guard isSolo, isMyTurn, overlay == nil else { return false }
        return !engine.history.isEmpty
    }
    var opponentName: String {
        switch mode {
        case .solo: return "AI"
        case .online: return "상대"
        case .tutorial, .puzzle: return "상대"
        }
    }
    var currentTutorialStep: TutorialStep? {
        isTutorial ? Self.tutorialSteps[tutorialStep] : nil
    }
    var currentPuzzle: Puzzle? {
        if case .puzzle(let puzzle) = mode { return puzzle }
        return nil
    }

    private var ai: AIPlayer?

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .solo(let difficulty):
            engine = GameEngine()
            localPlayer = .first
            ai = AIPlayer(difficulty: difficulty, me: .second)

        case .online(let client):
            engine = GameEngine()
            if case .matched(let me) = client.state {
                localPlayer = me
            } else {
                localPlayer = .first
            }
            client.onRemoteMove = { [weak self] move in
                self?.applyRemote(move)
            }
            client.onOpponentLeft = { [weak self] in
                guard let self, !self.engine.isFinished else { return }
                self.opponentLeft = true
            }

        case .tutorial:
            engine = GameEngine()
            localPlayer = .first
            loadTutorialStep(0)

        case .puzzle(let puzzle):
            engine = GameEngine(customBoard: puzzle.boardArray, turn: puzzle.toMove)
            localPlayer = puzzle.toMove
            // 퍼즐의 상대 응수는 강한 고정 난이도로
            ai = AIPlayer(difficulty: .hard, me: puzzle.toMove.opponent)
        }
        rebuildPieceIDs()
        refreshBanner()
        scheduleAIIfNeeded()
    }

    private func rebuildPieceIDs() {
        pieceIDs = [:]
        for i in 0..<GameEngine.cellCount where engine.board[i] != 0 {
            nextPieceID += 1
            pieceIDs[i] = nextPieceID
        }
    }

    private func movePieceID(_ move: Move) {
        pieceIDs[move.to] = pieceIDs.removeValue(forKey: move.from)
    }

    func cancelAllWork() {
        aiTask?.cancel()
    }

    // MARK: - 사용자 입력

    func tapCell(_ cell: Int) {
        guard isMyTurn, overlay == nil else { return }

        if GameEngine.owner(of: engine.board[cell]) == localPlayer {
            // 자기 말 선택/재선택
            selection = cell
            targets = engine.moves(from: cell)
            return
        }
        if selection != nil, let move = targets.first(where: { $0.to == cell }) {
            applyLocal(move)
            return
        }
        selection = nil
        targets = []
    }

    func undo() {
        guard canUndo else { return }
        // 내 마지막 수와 그 뒤 AI 응수를 함께 되돌린다
        engine.undoLastMove()
        if engine.turn != localPlayer { engine.undoLastMove() }
        selection = nil
        targets = []
        lastMove = engine.history.last?.move
        rebuildPieceIDs()
        refreshBanner()
    }

    func resign() {
        guard engine.isRoundRunning else { return }
        cancelAllWork()
        overlay = .matchWon(mine: false)
        recordStatsIfNeeded(winner: localPlayer.opponent)
        if case .online(let client) = mode { client.close() }
    }

    /// 라운드 종료 오버레이에서 "다음 라운드"
    func startNextRound() {
        guard case .roundWon = overlay else { return }
        try? engine.startNextRound()
        overlay = nil
        selection = nil
        targets = []
        lastMove = nil
        rebuildPieceIDs()
        refreshBanner()
        scheduleAIIfNeeded()
    }

    /// 튜토리얼 다음 단계 / 재시도, 퍼즐 재시도용 재시작
    func advanceTutorial() {
        switch overlay {
        case .tutorialStepDone(let last):
            if !last { loadTutorialStep(tutorialStep + 1) }
        case .tutorialRetry:
            loadTutorialStep(tutorialStep)
        default:
            break
        }
    }

    func retryPuzzle() {
        guard let puzzle = currentPuzzle else { return }
        cancelAllWork()
        engine = GameEngine(customBoard: puzzle.boardArray, turn: puzzle.toMove)
        puzzleMovesUsed = 0
        overlay = nil
        selection = nil
        targets = []
        lastMove = nil
        rebuildPieceIDs()
        refreshBanner()
    }

    // MARK: - 무브 적용

    private func applyLocal(_ move: Move) {
        guard let outcome = try? engine.apply(move, by: localPlayer) else { return }
        if case .online(let client) = mode {
            client.send(move: move)
        }
        if isPuzzle { puzzleMovesUsed += 1 }
        present(outcome)
    }

    private func applyRemote(_ move: Move) {
        guard let outcome = try? engine.apply(move, by: localPlayer.opponent) else { return }
        present(outcome)
    }

    // MARK: - 상태 반영

    private func present(_ outcome: MoveOutcome) {
        selection = nil
        targets = []
        if let applied = engine.history.last?.move {
            movePieceID(applied)
        }

        switch outcome {
        case .moved(let player, let move):
            lastMove = move

            if isTutorial {
                judgeTutorial(move)
                return
            }
            if isPuzzle, player == localPlayer {
                judgePuzzleAfterMyMove()
                if overlay != nil { return }
            }
            refreshBanner()
            scheduleAIIfNeeded()

        case .roundWon(let player, let round, _):
            lastMove = engine.history.last?.move
            if isTutorial {
                judgeTutorial(engine.history.last!.move)
                return
            }
            if isPuzzle {
                judgePuzzleRoundEnd(winner: player)
                return
            }
            overlay = .roundWon(mine: player == localPlayer, round: round)

        case .matchWon(let player, _):
            lastMove = engine.history.last?.move
            if isTutorial {
                judgeTutorial(engine.history.last!.move)
                return
            }
            if isPuzzle {
                judgePuzzleRoundEnd(winner: player)
                return
            }
            overlay = .matchWon(mine: player == localPlayer)
            recordStatsIfNeeded(winner: player)
        }
    }

    private func refreshBanner() {
        if let step = currentTutorialStep {
            banner = step.text
        } else if let puzzle = currentPuzzle {
            let left = puzzle.ownMoves - puzzleMovesUsed
            banner = "\(puzzle.ownMoves)수 안에 오아시스 도착 — 남은 수 \(left)"
        } else if engine.isRoundRunning {
            banner = isMyTurn
                ? "내 차례 — 말을 선택하세요"
                : "\(opponentName)의 차례…"
        }
    }

    // MARK: - 튜토리얼 판정

    private func loadTutorialStep(_ index: Int) {
        tutorialStep = index
        var board = [Int8](repeating: 0, count: GameEngine.cellCount)
        for (name, player) in Self.tutorialSteps[index].pieces {
            board[GameEngine.cellIndex(name)!] = Int8(player.rawValue + 1)
        }
        engine = GameEngine(customBoard: board, turn: .first)
        overlay = nil
        selection = nil
        targets = []
        lastMove = nil
        rebuildPieceIDs()
        refreshBanner()
    }

    private func judgeTutorial(_ move: Move) {
        let step = Self.tutorialSteps[tutorialStep]
        if step.isSatisfied(move) {
            overlay = .tutorialStepDone(last: tutorialStep == Self.tutorialSteps.count - 1)
        } else {
            overlay = .tutorialRetry
        }
    }

    // MARK: - 퍼즐 판정

    private func judgePuzzleAfterMyMove() {
        guard let puzzle = currentPuzzle else { return }
        // 허용 수를 다 썼는데 아직 승리하지 못함 → 실패
        if puzzleMovesUsed >= puzzle.ownMoves, engine.isRoundRunning {
            overlay = .puzzleFailed(reason: "\(puzzle.ownMoves)수 안에 도착하지 못했어요.")
        }
    }

    private func judgePuzzleRoundEnd(winner: Player) {
        guard let puzzle = currentPuzzle else { return }
        if winner == localPlayer, puzzleMovesUsed <= puzzle.ownMoves {
            StatsStore.shared.markPuzzleSolved(id: puzzle.id)
            let index = Puzzles.all.firstIndex { $0.id == puzzle.id } ?? 0
            overlay = .puzzleSolved(last: index == Puzzles.all.count - 1)
        } else {
            overlay = .puzzleFailed(reason: "상대가 먼저 도착했어요.")
        }
    }

    // MARK: - 전적

    private func recordStatsIfNeeded(winner: Player) {
        guard !statsRecorded, showsMatchScore else { return }
        statsRecorded = true
        let won = winner == localPlayer
        switch mode {
        case .solo(let difficulty):
            StatsStore.shared.recordSolo(difficulty: difficulty, won: won)
        case .online:
            StatsStore.shared.recordOnline(won: won)
        case .tutorial, .puzzle:
            break
        }
    }

    // MARK: - AI 턴 진행

    private var aiToMove: AIPlayer? {
        guard let ai, engine.isRoundRunning, engine.turn == ai.me, overlay == nil else { return nil }
        return ai
    }

    private func scheduleAIIfNeeded() {
        guard let aiPlayer = aiToMove else { return }
        aiTask?.cancel()
        let board = engine.board
        aiTask = Task { [weak self] in
            // 즉답이 어색하지 않도록 살짝 뜸을 들인다
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            let move = await Task.detached(priority: .userInitiated) {
                aiPlayer.chooseMove(board: board)
            }.value
            guard let self, !Task.isCancelled, let move,
                  self.engine.turn == aiPlayer.me, self.engine.isRoundRunning else { return }
            guard let outcome = try? self.engine.apply(move, by: aiPlayer.me) else { return }
            self.present(outcome)
        }
    }
}
