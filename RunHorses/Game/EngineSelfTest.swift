import Foundation

/// 엔진 규칙 검증 — 지형/배치/슬라이드/L자/승리 패턴/매치 흐름/AI를
/// JS 레퍼런스 구현(engine/test/)과 동일한 시나리오로 확인한다.
/// DEBUG 빌드에서 앱 시작 시 1회 실행된다.
enum EngineSelfTest {
    static func run() {
        #if DEBUG
        do {
            try testBoard()
            try testSlide()
            try testLShape()
            try testWinPattern()
            try testMatchFlow()
            try testUndo()
            try testAI()
            try testPuzzles()
            print("[EngineSelfTest] 지형·이동·승리·매치·AI·퍼즐 검증 통과 ✅")
        } catch {
            assertionFailure("[EngineSelfTest] 엔진 규칙 검증 실패: \(error)")
        }
        #endif
    }

    private enum TestError: Error { case mismatch(String) }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw TestError.mismatch(message) }
    }

    private static func emptyBoard() -> [Int8] {
        [Int8](repeating: 0, count: GameEngine.cellCount)
    }

    private static func idx(_ name: String) -> Int { GameEngine.cellIndex(name)! }

    // MARK: 보드

    static func testBoard() throws {
        try expect(GameEngine.cellIndex("f6") == GameEngine.center, "f6 = 중앙")
        try expect(GameEngine.terrain(at: GameEngine.center) == .oasis, "중앙은 오아시스")
        try expect(GameEngine.cellName(0) == "a1" && GameEngine.cellName(120) == "k11", "좌표 표기")

        // 초원: 중앙 맨해튼 거리 2 이내 12칸
        let meadowCells = ["d6", "e5", "e6", "e7", "f4", "f5", "f7", "f8", "g5", "g6", "g7", "h6"]
        for name in meadowCells {
            try expect(GameEngine.terrain(at: idx(name)) == .meadow, "\(name)은 초원")
        }
        let meadowCount = (0..<GameEngine.cellCount).filter { GameEngine.terrain(at: $0) == .meadow }.count
        try expect(meadowCount == 12, "초원 칸 수 = 12")
        for name in ["a1", "f1", "d5", "e4", "c6", "f9", "k11"] {
            try expect(GameEngine.terrain(at: idx(name)) == .desert, "\(name)은 사막")
        }

        // 초기 배치: 각 10개, 오아시스는 빈 칸
        let board = GameEngine.initialBoard()
        try expect(board.filter { $0 == 1 }.count == 10, "밤색 10개")
        try expect(board.filter { $0 == 2 }.count == 10, "흰색 10개")
        try expect(board[GameEngine.center] == 0, "오아시스는 빈 칸")
        try expect(!GameEngine.legalMoves(on: board, for: .first).isEmpty, "초기 밤색 합법수 존재")
        try expect(!GameEngine.legalMoves(on: board, for: .first).contains { $0.to == GameEngine.center },
                   "초기에 즉시 승리 수 없음")
    }

    // MARK: 슬라이드

    static func testSlide() throws {
        var board = emptyBoard()
        board[idx("c3")] = 1
        let slides = GameEngine.moves(on: board, from: idx("c3")).filter { $0.kind == .slide }
        let dests = Set(slides.map { GameEngine.cellName($0.to) })
        try expect(dests == ["a3", "k3", "c1", "c11"], "빈 보드에서 가장자리까지: \(dests)")

        board[idx("c8")] = 2 // 우측 이동을 가로막음
        let blocked = GameEngine.moves(on: board, from: idx("c3")).filter { $0.kind == .slide }
        try expect(blocked.contains { GameEngine.cellName($0.to) == "c7" }, "블로커 직전 정지")
        try expect(!blocked.contains { GameEngine.cellName($0.to) == "c8" }, "블로커 칸 도착 불가")

        // 바로 옆이 막히면 그 방향 이동 불가
        var corner = emptyBoard()
        corner[idx("a1")] = 1
        corner[idx("a2")] = 2
        corner[idx("b1")] = 2
        try expect(GameEngine.moves(on: corner, from: idx("a1")).filter { $0.kind == .slide }.isEmpty,
                   "포위된 말의 슬라이드 없음")
    }

    // MARK: L자

    static func testLShape() throws {
        var board = emptyBoard()
        board[idx("c3")] = 1 // 도착지 8칸 모두 사막
        try expect(GameEngine.moves(on: board, from: idx("c3")).filter { $0.kind == .lshape }.count == 8,
                   "c3 나이트 8방향")

        var nearCenter = emptyBoard()
        nearCenter[idx("d5")] = 1 // 도착지에 f6(오아시스), e7·f4(초원) 포함
        let lmoves = GameEngine.moves(on: nearCenter, from: idx("d5")).filter { $0.kind == .lshape }
        let dests = Set(lmoves.map { GameEngine.cellName($0.to) })
        try expect(!dests.contains("f6"), "오아시스 L자 도착 불가")
        try expect(!dests.contains("e7") && !dests.contains("f4"), "초원 L자 도착 불가")
        try expect(dests.contains("b4") && dests.contains("c3"), "사막은 가능")

        // 점프: 포위돼도 나이트 이동은 가능
        var corner = emptyBoard()
        for name in ["a1", "a2", "b1", "b2"] { corner[idx(name)] = name == "a1" ? 1 : 2 }
        let jumps = GameEngine.moves(on: corner, from: idx("a1")).filter { $0.kind == .lshape }
        try expect(Set(jumps.map { GameEngine.cellName($0.to) }) == ["b3", "c2"], "포위 점프")
    }

    // MARK: 승리 패턴 (위키의 필승 구조)

    static func testWinPattern() throws {
        var board = emptyBoard()
        board[idx("e6")] = 2 // 블로커 (소유 불문)
        board[idx("k6")] = 1
        let wins = GameEngine.moves(on: board, from: idx("k6")).filter { $0.to == GameEngine.center }
        try expect(wins.count == 1 && wins[0].kind == .slide, "e6 블로커 → k6이 f6에 정지")

        board[idx("e6")] = 0 // 블로커 제거 → 오아시스를 지나쳐 미끄러진다
        let overshoot = GameEngine.moves(on: board, from: idx("k6"))
        try expect(!overshoot.contains { $0.to == GameEngine.center }, "블로커 없으면 통과")
        try expect(overshoot.contains { GameEngine.cellName($0.to) == "a6" }, "반대편 끝까지")
    }

    // MARK: 매치 흐름 (3판 2선승, 선공 교대)

    static func testMatchFlow() throws {
        var engine = GameEngine()
        try expect(engine.roundNumber == 1 && engine.turn == .first, "1라운드 밤색 선공")

        // 잘못된 수 거부
        do {
            _ = try engine.apply(Move(from: 0, to: 1, kind: .slide), by: .second)
            try expect(false, "차례 아닌 수를 거부해야 함")
        } catch let error as EngineError {
            try expect(error == .notYourTurn, "notYourTurn")
        }

        // 커스텀 포지션으로 라운드 승리 → 라운드 전환 검증
        var custom = emptyBoard()
        custom[idx("e6")] = 2
        custom[idx("k6")] = 1
        custom[idx("a11")] = 2
        var round = GameEngine(customBoard: custom, turn: .first)
        let win = round.legalMoves(for: .first).first { $0.to == GameEngine.center }!
        let outcome = try round.apply(win, by: .first)
        try expect(outcome == .roundWon(player: .first, round: 1, wins: [1, 0]), "라운드 승리 판정")
        try round.startNextRound()
        try expect(round.roundNumber == 2 && round.turn == .second, "2라운드 흰색 선공")
    }

    // MARK: 무르기

    static func testUndo() throws {
        var engine = GameEngine()
        let before = engine.board
        let move = engine.legalMoves(for: .first)[0]
        _ = try engine.apply(move, by: .first)
        try expect(engine.turn == .second, "수 적용 후 차례 전환")
        try expect(engine.undoLastMove(), "무르기 성공")
        try expect(engine.board == before && engine.turn == .first, "보드·차례 복원")
        try expect(!engine.undoLastMove(), "더 무를 수 없음")
    }

    // MARK: AI

    static func testAI() throws {
        // 즉시 승리 수를 항상 선택한다
        var board = emptyBoard()
        board[idx("e6")] = 2
        board[idx("k6")] = 1
        board[idx("a1")] = 1
        for difficulty in AIPlayer.Difficulty.allCases {
            let ai = AIPlayer(difficulty: difficulty, me: .first)
            let move = ai.chooseMove(board: board)
            try expect(move?.to == GameEngine.center, "\(difficulty.rawValue): 즉시 승리 선택")
        }

        // 초기 배치에서 합법수를 반환한다
        let opening = AIPlayer(difficulty: .normal, me: .first)
            .chooseMove(board: GameEngine.initialBoard())
        try expect(opening != nil, "초기 배치에서 수 반환")
        try expect(GameEngine.legalMoves(on: GameEngine.initialBoard(), for: .first)
            .contains(opening!), "반환한 수는 합법수")
    }

    // MARK: 퍼즐 데이터

    static func testPuzzles() throws {
        try expect(!Puzzles.all.isEmpty, "퍼즐 존재")
        for puzzle in Puzzles.all {
            try expect(puzzle.board.count == GameEngine.cellCount, "\(puzzle.id) 보드 크기")
            let board = puzzle.boardArray
            let wins = GameEngine.legalMoves(on: board, for: puzzle.toMove)
                .filter { $0.to == GameEngine.center }
            if puzzle.ownMoves == 1 {
                try expect(wins.count == 1, "\(puzzle.id): 1수 퍼즐은 즉시 승리 수가 정확히 1개")
            } else {
                try expect(wins.isEmpty, "\(puzzle.id): 2수 퍼즐은 즉시 승리 없음")
            }
        }
    }
}
