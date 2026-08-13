import Foundation

/// 말달리자 AI — 네가맥스 + 알파-베타 + 조브리스트 트랜스포지션 테이블 + 반복 심화.
/// engine/src/ai.js(JS 레퍼런스 구현)의 포팅. 값 타입 보드([Int8]) 위에서 동작한다.
struct AIPlayer: Sendable {
    enum Difficulty: String, CaseIterable, Sendable {
        case easy
        case normal
        case hard
        case expert

        var label: String {
            switch self {
            case .easy: return "쉬움"
            case .normal: return "보통"
            case .hard: return "어려움"
            case .expert: return "전문가"
            }
        }

        /// (고정 깊이, 시간 예산, 상위 후보 무작위 폭)
        var settings: (depth: Int?, timeLimit: TimeInterval?, randomness: Int) {
            switch self {
            case .easy: return (1, nil, 3)
            case .normal: return (2, nil, 1)
            case .hard: return (3, nil, 1)
            case .expert: return (nil, 0.8, 1)
            }
        }
    }

    let difficulty: Difficulty
    let me: Player

    private static let winScore = 100_000
    private static let winThreshold = 90_000
    private static let maxDepth = 9

    // MARK: 조브리스트 해시 (결정적 시드)

    private static let zobrist: [[UInt64]] = {
        var state: UInt64 = 0xC0FFEE_5EED
        func next() -> UInt64 {
            // SplitMix64
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        return (0..<2).map { _ in (0..<GameEngine.cellCount).map { _ in next() } }
    }()
    private static let zobristTurn: UInt64 = 0x5EED_1234_ABCD_EF01

    private static func hash(board: [Int8], toMove: Player) -> UInt64 {
        var h: UInt64 = toMove == .first ? 0 : zobristTurn
        for i in 0..<GameEngine.cellCount where board[i] != 0 {
            h ^= zobrist[Int(board[i]) - 1][i]
        }
        return h
    }

    // MARK: 평가 함수

    /// 각 방향에서 중앙에 가장 가까운 말이 오아시스에 "정확히 멈출 수 있는지" 스캔.
    /// wins = 즉시 승리 가능 수, near = 블로커만 생기면 승리하는 잠재 위협
    private static func scanCenterLines(_ board: [Int8]) -> (wins: [Int], near: [Int]) {
        var wins = [0, 0]
        var near = [0, 0]
        let size = GameEngine.boardSize
        let cr = GameEngine.center / size
        let cc = GameEngine.center % size

        for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            var r = cr + dr
            var c = cc + dc
            var piece: Int8 = 0
            while (0..<size).contains(r), (0..<size).contains(c) {
                let v = board[r * size + c]
                if v != 0 {
                    piece = v
                    break
                }
                r += dr
                c += dc
            }
            guard piece != 0 else { continue }
            let blocked = board[(cr - dr) * size + (cc - dc)] != 0
            if blocked { wins[Int(piece) - 1] += 1 } else { near[Int(piece) - 1] += 1 }
        }
        return (wins, near)
    }

    private static func evaluate(_ board: [Int8], for player: Player) -> Int {
        let (wins, near) = scanCenterLines(board)
        let mine = player.rawValue
        let theirs = player.opponent.rawValue
        var score = 6000 * (min(wins[mine], 2) - min(wins[theirs], 2))
        score += 120 * (near[mine] - near[theirs])

        let size = GameEngine.boardSize
        for i in 0..<GameEngine.cellCount {
            let v = board[i]
            guard v != 0 else { continue }
            let sign = Int(v) - 1 == mine ? 1 : -1
            let r = i / size
            let c = i % size
            let dist = abs(r - 5) + abs(c - 5)
            score += sign * (10 - dist) * 3 // 중앙 접근
            if r == 5 || c == 5 { score += sign * 6 } // 중앙 라인 점유
        }
        return score
    }

    private static func orderKey(_ move: Move) -> Int {
        if move.to == GameEngine.center { return 1_000_000_000 }
        let size = GameEngine.boardSize
        let dTo = abs(move.to / size - 5) + abs(move.to % size - 5)
        let dFrom = abs(move.from / size - 5) + abs(move.from % size - 5)
        var key = (dFrom - dTo) * 10
        if move.to / size == 5 || move.to % size == 5 { key += 5 }
        return key
    }

    // MARK: 탐색

    private struct TTEntry {
        let depth: Int
        let score: Int
        let flag: Int // 0 exact, 1 lower, 2 upper
        let move: Move?
    }

    private final class Search {
        var tt: [UInt64: TTEntry] = [:]
        let deadline: Date?
        var timedOut = false
        private var nodes = 0

        init(deadline: Date?) {
            self.deadline = deadline
        }

        func checkTime() -> Bool {
            nodes += 1
            if nodes & 1023 == 0, let deadline, Date() > deadline {
                timedOut = true
            }
            return timedOut
        }

        /// toMove 관점 점수. 시간 초과 시 board를 원상 복원하고 nil 반환.
        func negamax(_ board: inout [Int8], hash: UInt64, depth: Int,
                     alpha: Int, beta: Int, toMove: Player, ply: Int) -> Int? {
            if checkTime() { return nil }

            var alpha = alpha
            var beta = beta
            let alphaOrig = alpha
            var ttMove: Move?
            if let entry = tt[hash] {
                ttMove = entry.move
                if entry.depth >= depth {
                    var s = entry.score
                    if s > AIPlayer.winThreshold { s -= ply } else if s < -AIPlayer.winThreshold { s += ply }
                    switch entry.flag {
                    case 0: return s
                    case 1: if s > alpha { alpha = s }
                    default: if s < beta { beta = s }
                    }
                    if alpha >= beta { return s }
                }
            }

            var moves = GameEngine.legalMoves(on: board, for: toMove)
            if moves.isEmpty { return 0 } // 이동 불가 = 무승부 취급
            if moves.contains(where: { $0.to == GameEngine.center }) {
                return AIPlayer.winScore - ply
            }
            if depth == 0 { return AIPlayer.evaluate(board, for: toMove) }

            moves.sort {
                let a = ($0 == ttMove ? 2_000_000_000 : AIPlayer.orderKey($0))
                let b = ($1 == ttMove ? 2_000_000_000 : AIPlayer.orderKey($1))
                return a > b
            }

            let piece = toMove.rawValue
            var best = Int.min
            var bestMove: Move?
            for move in moves {
                let childHash = hash
                    ^ AIPlayer.zobrist[piece][move.from]
                    ^ AIPlayer.zobrist[piece][move.to]
                    ^ AIPlayer.zobristTurn
                let captured = board[move.to]
                board[move.to] = board[move.from]
                board[move.from] = 0
                let child = negamax(&board, hash: childHash, depth: depth - 1,
                                    alpha: -beta, beta: -alpha,
                                    toMove: toMove.opponent, ply: ply + 1)
                board[move.from] = board[move.to]
                board[move.to] = captured
                guard let child else { return nil } // 시간 초과 전파 (보드는 복원됨)
                let score = -child
                if score > best {
                    best = score
                    bestMove = move
                }
                if best > alpha { alpha = best }
                if alpha >= beta { break }
            }

            var stored = best
            if stored > AIPlayer.winThreshold { stored += ply } else if stored < -AIPlayer.winThreshold { stored -= ply }
            let flag = best <= alphaOrig ? 2 : (best >= beta ? 1 : 0)
            if tt.count > 1 << 20 { tt.removeAll(keepingCapacity: true) } // 메모리 상한
            tt[hash] = TTEntry(depth: depth, score: stored, flag: flag, move: bestMove)
            return best
        }

        /// 루트 탐색 — 각 수의 점수. 시간 초과 시 nil.
        func rootSearch(_ board: inout [Int8], player: Player, depth: Int) -> [(move: Move, score: Int)]? {
            var moves = GameEngine.legalMoves(on: board, for: player)
            if let win = moves.first(where: { $0.to == GameEngine.center }) {
                return [(win, AIPlayer.winScore)]
            }
            let hash = AIPlayer.hash(board: board, toMove: player)
            let ttMove = tt[hash]?.move
            moves.sort {
                let a = ($0 == ttMove ? 2_000_000_000 : AIPlayer.orderKey($0))
                let b = ($1 == ttMove ? 2_000_000_000 : AIPlayer.orderKey($1))
                return a > b
            }

            var scored: [(move: Move, score: Int)] = []
            var alpha = Int.min + 1
            let piece = player.rawValue
            for move in moves {
                let childHash = hash
                    ^ AIPlayer.zobrist[piece][move.from]
                    ^ AIPlayer.zobrist[piece][move.to]
                    ^ AIPlayer.zobristTurn
                board[move.to] = board[move.from]
                board[move.from] = 0
                let child = negamax(&board, hash: childHash, depth: depth - 1,
                                    alpha: Int.min + 1, beta: -alpha,
                                    toMove: player.opponent, ply: 1)
                board[move.from] = board[move.to]
                board[move.to] = 0
                guard let child else { return nil }
                let score = -child
                scored.append((move, score))
                if score > alpha { alpha = score }
            }
            return scored.sorted { $0.score > $1.score }
        }
    }

    // MARK: 수 선택

    /// 현재 보드에서 최선 수를 고른다. 무거운 계산이므로 백그라운드에서 부를 것.
    func chooseMove(board: [Int8]) -> Move? {
        let settings = difficulty.settings
        var work = board
        var scored: [(move: Move, score: Int)]?

        if let timeLimit = settings.timeLimit {
            // 반복 심화 — 시간이 다 되면 마지막으로 완료한 깊이의 결과 사용
            let search = Search(deadline: Date().addingTimeInterval(timeLimit))
            for depth in 1...Self.maxDepth {
                guard let result = search.rootSearch(&work, player: me, depth: depth) else { break }
                scored = result
                if result.first!.score > Self.winThreshold { break }
            }
            if scored == nil {
                scored = Search(deadline: nil).rootSearch(&work, player: me, depth: 1)
            }
        } else {
            scored = Search(deadline: nil).rootSearch(&work, player: me, depth: settings.depth ?? 2)
        }

        guard let scored, !scored.isEmpty else { return nil }
        let best = scored[0].score
        // 동점(또는 randomness 상위권) 내에서 무작위 선택
        let pool = scored.enumerated().filter { $0.offset < settings.randomness || $0.element.score == best }
        return pool.randomElement()?.element.move
    }
}
