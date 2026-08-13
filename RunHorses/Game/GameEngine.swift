import Foundation

/// 말달리자의 두 플레이어. first = 밤색 말(1·3라운드 선공), second = 흰 말.
enum Player: Int, Codable, CaseIterable {
    case first = 0
    case second = 1

    var opponent: Player { self == .first ? .second : .first }
    var label: String { self == .first ? "밤색" : "흰색" }
    var horseGlyph: String { self == .first ? "♞" : "♘" }
}

/// 한 수 — 온라인 릴레이로 그대로 직렬화된다.
struct Move: Codable, Equatable {
    enum Kind: String, Codable {
        case slide
        case lshape
    }

    let from: Int
    let to: Int
    let kind: Kind
}

enum MoveOutcome: Equatable {
    /// 이동만 하고 라운드는 계속
    case moved(player: Player, move: Move)
    /// 오아시스 도착 — 라운드 승리 (매치는 계속)
    case roundWon(player: Player, round: Int, wins: [Int])
    /// 매치 승리 (2라운드 선취)
    case matchWon(player: Player, wins: [Int])
}

enum EngineError: Error, Equatable {
    case notYourTurn
    case roundNotRunning
    case illegalMove
    case roundStillRunning
    case matchFinished
}

/// 말달리자 규칙 상태기계 (순수 값 타입 — 양쪽 기기에서 동일 재현).
/// 규칙 명세: docs/rules-spec.md, 레퍼런스 구현: engine/src/ (JS)
struct GameEngine {
    // MARK: 보드 상수

    static let boardSize = 11
    static let cellCount = 121
    static let center = 60 // f6
    static let totalRounds = 3
    static let winsNeeded = 2

    enum Terrain {
        case desert
        case meadow
        case oasis
    }

    /// 초원 = 중앙에서 맨해튼 거리 2 이내의 12칸 다이아몬드
    static func terrain(at index: Int) -> Terrain {
        if index == center { return .oasis }
        let r = index / boardSize
        let c = index % boardSize
        if abs(r - 5) + abs(c - 5) <= 2 { return .meadow }
        return .desert
    }

    /// 'f6' 형식 좌표 (행 a~k, 열 1~11)
    static func cellName(_ index: Int) -> String {
        let r = index / boardSize
        let c = index % boardSize
        return String(UnicodeScalar(UInt8(97 + r))) + String(c + 1)
    }

    static func cellIndex(_ name: String) -> Int? {
        guard let rowScalar = name.unicodeScalars.first,
              let col = Int(name.dropFirst()) else { return nil }
        let r = Int(rowScalar.value) - 97
        let c = col - 1
        guard (0..<boardSize).contains(r), (0..<boardSize).contains(c) else { return nil }
        return r * boardSize + c
    }

    /// 초기 배치 — 대각 방향으로 마주보는 두 코너에 ㄱ자 형태로 5개씩.
    /// first(밤색): 좌상 + 우하 / second(흰색): 우상 + 좌하
    static let initialFirst = ["a1", "a2", "a3", "b1", "c1", "i11", "j11", "k11", "k10", "k9"]
    static let initialSecond = ["a9", "a10", "a11", "b11", "c11", "i1", "j1", "k1", "k2", "k3"]

    static func initialBoard() -> [Int8] {
        var board = [Int8](repeating: 0, count: cellCount)
        for name in initialFirst { board[cellIndex(name)!] = 1 }
        for name in initialSecond { board[cellIndex(name)!] = 2 }
        return board
    }

    // MARK: 상태

    /// 0 = 빈 칸, 1 = first의 말, 2 = second의 말
    private(set) var board: [Int8]
    private(set) var turn: Player
    private(set) var roundNumber = 1
    private(set) var roundWins = [0, 0]
    /// 현재 라운드의 승자 (nil이면 진행 중)
    private(set) var roundWinner: Player?
    private(set) var matchWinner: Player?
    /// 현재 라운드의 수순 (무르기·리플레이용)
    private(set) var history: [(move: Move, player: Player)] = []

    var isFinished: Bool { matchWinner != nil }
    var isRoundRunning: Bool { roundWinner == nil && matchWinner == nil }

    /// 정규 매치 시작 (1라운드, 밤색 선공)
    init() {
        board = Self.initialBoard()
        turn = .first
    }

    /// 튜토리얼·퍼즐용 커스텀 포지션 시작
    init(customBoard: [Int8], turn: Player) {
        precondition(customBoard.count == Self.cellCount)
        board = customBoard
        self.turn = turn
    }

    // MARK: 이동 생성

    static func owner(of value: Int8) -> Player? {
        switch value {
        case 1: return .first
        case 2: return .second
        default: return nil
        }
    }

    /// 특정 칸의 말이 갈 수 있는 모든 수
    static func moves(on board: [Int8], from: Int) -> [Move] {
        var result: [Move] = []
        let r = from / boardSize
        let c = from % boardSize

        // 슬라이드: 가장자리나 다른 말에 막히기 직전까지 (중간 정지 불가)
        for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            var nr = r + dr
            var nc = c + dc
            var last = -1
            while (0..<boardSize).contains(nr), (0..<boardSize).contains(nc),
                  board[nr * boardSize + nc] == 0 {
                last = nr * boardSize + nc
                nr += dr
                nc += dc
            }
            if last != -1 {
                result.append(Move(from: from, to: last, kind: .slide))
            }
        }

        // L자: 나이트 점프, 도착 칸이 비어있는 사막 칸일 때만
        for (dr, dc) in [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)] {
            let nr = r + dr
            let nc = c + dc
            guard (0..<boardSize).contains(nr), (0..<boardSize).contains(nc) else { continue }
            let to = nr * boardSize + nc
            if board[to] == 0, terrain(at: to) == .desert {
                result.append(Move(from: from, to: to, kind: .lshape))
            }
        }
        return result
    }

    static func legalMoves(on board: [Int8], for player: Player) -> [Move] {
        var result: [Move] = []
        let mark = Int8(player.rawValue + 1)
        for i in 0..<cellCount where board[i] == mark {
            result.append(contentsOf: moves(on: board, from: i))
        }
        return result
    }

    func legalMoves(for player: Player) -> [Move] {
        guard isRoundRunning else { return [] }
        return Self.legalMoves(on: board, for: player)
    }

    func moves(from index: Int) -> [Move] {
        guard isRoundRunning, Self.owner(of: board[index]) == turn else { return [] }
        return Self.moves(on: board, from: index)
    }

    // MARK: 수 적용

    mutating func apply(_ move: Move, by player: Player) throws -> MoveOutcome {
        guard matchWinner == nil else { throw EngineError.matchFinished }
        guard roundWinner == nil else { throw EngineError.roundNotRunning }
        guard player == turn else { throw EngineError.notYourTurn }
        guard Self.owner(of: board[move.from]) == player,
              Self.moves(on: board, from: move.from).contains(move) else {
            throw EngineError.illegalMove
        }

        board[move.to] = board[move.from]
        board[move.from] = 0
        history.append((move, player))

        // 승리 조건: 오아시스 도착
        if move.to == Self.center {
            roundWinner = player
            roundWins[player.rawValue] += 1
            if roundWins[player.rawValue] >= Self.winsNeeded {
                matchWinner = player
                return .matchWon(player: player, wins: roundWins)
            }
            return .roundWon(player: player, round: roundNumber, wins: roundWins)
        }

        turn = player.opponent
        return .moved(player: player, move: move)
    }

    /// 라운드 종료 후 다음 라운드 시작 — 선공 교대 (1·3라운드 first, 2라운드 second)
    mutating func startNextRound() throws {
        guard matchWinner == nil else { throw EngineError.matchFinished }
        guard roundWinner != nil else { throw EngineError.roundStillRunning }
        roundNumber += 1
        board = Self.initialBoard()
        turn = roundNumber % 2 == 1 ? .first : .second
        roundWinner = nil
        history = []
    }

    /// 현재 라운드의 마지막 수를 무른다 (1인용 전용, 라운드 경계는 넘지 못함)
    @discardableResult
    mutating func undoLastMove() -> Bool {
        guard let last = history.popLast() else { return false }
        board[last.move.from] = board[last.move.to]
        board[last.move.to] = 0
        if roundWinner == last.player {
            roundWins[last.player.rawValue] -= 1
            roundWinner = nil
            matchWinner = nil
        }
        turn = last.player
        return true
    }
}
