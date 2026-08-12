// 말 달리자 — AI
// 네가맥스 + 알파-베타 + 조브리스트 해시 트랜스포지션 테이블 + 반복 심화(시간제한)
import {
  CELLS, CENTER, EMPTY, P1, P2, rc, opponent,
} from './board.js';
import { legalMoves, applyMove, undoMove, isWinningMove } from './rules.js';

const WIN_SCORE = 100000;
const WIN_THRESHOLD = 90000; // 이 이상이면 승리 확정 점수로 취급 (플라이 보정 대상)

// mulberry32 — 재현 가능한 시뮬레이션을 위한 시드 RNG
export function makeRng(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0;
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// --- 조브리스트 해시 (32비트, 셀×말 + 차례) ---
const ZOBRIST = (() => {
  const rng = makeRng(0xc0ffee);
  const table = { [P1]: new Int32Array(CELLS), [P2]: new Int32Array(CELLS) };
  for (const p of [P1, P2]) {
    for (let i = 0; i < CELLS; i++) table[p][i] = (rng() * 0x100000000) | 0;
  }
  return table;
})();
const ZOBRIST_TURN = 0x5eed1234 | 0;

export function hashBoard(board, toMove) {
  let h = toMove === P1 ? 0 : ZOBRIST_TURN;
  for (let i = 0; i < CELLS; i++) {
    if (board[i] !== EMPTY) h ^= ZOBRIST[board[i]][i];
  }
  return h | 0;
}

// --- 오아시스 진입 가능성 스캔 ---
// 각 방향에서 중앙에 가장 가까운 말을 찾아, 그 말이 슬라이드로 오아시스에
// "정확히 멈출 수 있는지"(반대편 인접 칸에 블로커 존재 + 경로 깨끗)를 판정한다.
function scanCenterLines(board) {
  const result = {
    [P1]: { wins: 0, near: 0 },
    [P2]: { wins: 0, near: 0 },
  };
  const [cr, cc] = rc(CENTER);
  const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];

  for (const [dr, dc] of dirs) {
    let r = cr + dr;
    let c = cc + dc;
    let piece = EMPTY;
    while (r >= 0 && r < 11 && c >= 0 && c < 11) {
      const v = board[r * 11 + c];
      if (v !== EMPTY) { piece = v; break; }
      r += dr;
      c += dc;
    }
    if (piece === EMPTY) continue;
    // 그 말이 중앙으로 미끄러질 때 멈춰줄 블로커: 반대편 인접 칸
    const blocked = board[(cr - dr) * 11 + (cc - dc)] !== EMPTY;
    if (blocked) result[piece].wins += 1;
    else result[piece].near += 1;
  }
  return result;
}

// player 관점의 정적 평가
export function evaluate(board, player) {
  const opp = opponent(player);
  const lines = scanCenterLines(board);
  let score = 0;

  score += 6000 * Math.min(lines[player].wins, 2);
  score -= 6000 * Math.min(lines[opp].wins, 2);
  score += 120 * lines[player].near;
  score -= 120 * lines[opp].near;

  for (let i = 0; i < CELLS; i++) {
    const v = board[i];
    if (v === EMPTY) continue;
    const sign = v === player ? 1 : -1;
    const r = (i / 11) | 0;
    const c = i % 11;
    const dist = Math.abs(r - 5) + Math.abs(c - 5);
    score += sign * (10 - dist) * 3; // 중앙 접근
    if (r === 5 || c === 5) score += sign * 6; // 중앙 라인 점유
  }
  return score;
}

// 이동 정렬 점수 (TT 최선 수는 별도로 최우선)
function moveOrderKey(m) {
  if (isWinningMove(m)) return 1e9;
  const [r, c] = rc(m.to);
  const [fr, fc] = rc(m.from);
  const dTo = Math.abs(r - 5) + Math.abs(c - 5);
  const dFrom = Math.abs(fr - 5) + Math.abs(fc - 5);
  let key = (dFrom - dTo) * 10;
  if (r === 5 || c === 5) key += 5;
  return key;
}

const TT_EXACT = 0;
const TT_LOWER = 1;
const TT_UPPER = 2;

class SearchTimeout extends Error {}

// 탐색 컨텍스트: 트랜스포지션 테이블 + 시간 예산
class Search {
  constructor(options = {}) {
    this.tt = new Map();
    // V8 Map 최대 크기(약 2^24) 초과 방지: 상한 도달 시 테이블을 비우고 계속한다
    this.maxTtEntries = options.maxTtEntries ?? 1 << 22;
    this.deadline = options.deadline ?? Infinity;
    this.nodes = 0;
  }

  checkTime() {
    if ((this.nodes & 1023) === 0 && Date.now() > this.deadline) {
      throw new SearchTimeout();
    }
  }

  negamax(board, hash, depth, alpha, beta, toMove, ply) {
    this.nodes += 1;
    this.checkTime();

    const alphaOrig = alpha;
    const entry = this.tt.get(hash);
    let ttMove = null;
    if (entry) {
      ttMove = entry.move;
      if (entry.depth >= depth) {
        let s = entry.score;
        if (s > WIN_THRESHOLD) s -= ply;
        else if (s < -WIN_THRESHOLD) s += ply;
        if (entry.flag === TT_EXACT) return s;
        if (entry.flag === TT_LOWER && s > alpha) alpha = s;
        else if (entry.flag === TT_UPPER && s < beta) beta = s;
        if (alpha >= beta) return s;
      }
    }

    const moves = legalMoves(board, toMove);
    if (moves.length === 0) return 0; // 이동 불가 = 무승부 취급

    for (const m of moves) {
      if (isWinningMove(m)) return WIN_SCORE - ply;
    }
    if (depth === 0) return evaluate(board, toMove);

    // 정렬: TT 수 최우선, 나머지는 휴리스틱
    moves.sort((a, b) => {
      const aTt = ttMove && a.from === ttMove.from && a.to === ttMove.to ? 1 : 0;
      const bTt = ttMove && b.from === ttMove.from && b.to === ttMove.to ? 1 : 0;
      if (aTt !== bTt) return bTt - aTt;
      return moveOrderKey(b) - moveOrderKey(a);
    });

    let best = -Infinity;
    let bestMoveHere = null;
    const piece = toMove;
    for (const m of moves) {
      const childHash = (hash
        ^ ZOBRIST[piece][m.from] ^ ZOBRIST[piece][m.to] ^ ZOBRIST_TURN) | 0;
      applyMove(board, m);
      let score;
      try {
        score = -this.negamax(
          board, childHash, depth - 1, -beta, -alpha, opponent(toMove), ply + 1,
        );
      } finally {
        // 시간 초과 예외로 중단되어도 보드를 반드시 복원한다
        undoMove(board, m);
      }
      if (score > best) {
        best = score;
        bestMoveHere = m;
      }
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }

    // TT 저장 (승리 점수는 플라이 무관 형태로 보정해 저장)
    let stored = best;
    if (stored > WIN_THRESHOLD) stored += ply;
    else if (stored < -WIN_THRESHOLD) stored -= ply;
    const flag = best <= alphaOrig ? TT_UPPER : best >= beta ? TT_LOWER : TT_EXACT;
    if (this.tt.size >= this.maxTtEntries) this.tt.clear();
    this.tt.set(hash, { depth, score: stored, flag, move: bestMoveHere });

    return best;
  }

  // 루트 탐색: 각 수의 점수 목록 반환
  rootSearch(board, player, depth) {
    const moves = legalMoves(board, player);
    const win = moves.find(isWinningMove);
    if (win) return [{ m: win, score: WIN_SCORE }];

    const hash = hashBoard(board, player);
    const entry = this.tt.get(hash);
    const ttMove = entry?.move ?? null;
    moves.sort((a, b) => {
      const aTt = ttMove && a.from === ttMove.from && a.to === ttMove.to ? 1 : 0;
      const bTt = ttMove && b.from === ttMove.from && b.to === ttMove.to ? 1 : 0;
      if (aTt !== bTt) return bTt - aTt;
      return moveOrderKey(b) - moveOrderKey(a);
    });

    const scored = [];
    let alpha = -Infinity;
    for (const m of moves) {
      const childHash = (hash
        ^ ZOBRIST[player][m.from] ^ ZOBRIST[player][m.to] ^ ZOBRIST_TURN) | 0;
      applyMove(board, m);
      let score;
      try {
        score = -this.negamax(
          board, childHash, depth - 1, -Infinity, -alpha, opponent(player), 1,
        );
      } finally {
        // 시간 초과 예외로 중단되어도 보드를 반드시 복원한다
        undoMove(board, m);
      }
      scored.push({ m, score });
      if (score > alpha) alpha = score;
    }
    scored.sort((a, b) => b.score - a.score);
    return scored;
  }
}

// 난이도 프리셋
export const DIFFICULTY = {
  easy: { depth: 1, randomness: 3 },   // 상위 3개 수 중 무작위
  normal: { depth: 2, randomness: 1 },
  hard: { depth: 3, randomness: 1 },
  expert: { timeMs: 800, maxDepth: 9, randomness: 1 }, // 반복 심화 + 시간제한
};

// 최선 수 선택.
// options: { depth } 고정 깊이, 또는 { timeMs, maxDepth } 반복 심화.
//          { randomness, rng } 상위권 무작위 선택.
export function bestMove(board, player, options = {}) {
  const randomness = options.randomness ?? 1;
  const rng = options.rng ?? Math.random;

  const moves = legalMoves(board, player);
  if (moves.length === 0) return null;
  const win = moves.find(isWinningMove);
  if (win) return win;

  let scored = null;
  if (options.timeMs) {
    // 반복 심화: 시간이 다 되면 마지막으로 완료한 깊이의 결과 사용
    const search = new Search({ deadline: Date.now() + options.timeMs });
    const maxDepth = options.maxDepth ?? 9;
    for (let d = 1; d <= maxDepth; d++) {
      try {
        scored = search.rootSearch(board, player, d);
      } catch (e) {
        if (e instanceof SearchTimeout) break;
        throw e;
      }
      if (scored[0].score > WIN_THRESHOLD) break; // 승리 라인 확정
    }
    if (!scored) scored = new Search().rootSearch(board, player, 1);
  } else {
    const depth = options.depth ?? 2;
    scored = new Search().rootSearch(board, player, depth);
  }

  const pool = scored.filter(
    (s, i) => i < randomness || s.score === scored[0].score,
  );
  return pool[Math.floor(rng() * pool.length)].m;
}

// 탐색 점수 조회: player가 둘 차례일 때 최선 수의 점수 (player 관점)
export function searchScore(board, player, depth) {
  return new Search().rootSearch(board, player, depth)[0].score;
}

// 강제승 판정: player가 plies 플라이 안에 승리를 강제할 수 있으면 승리 수를 반환
export function forcedWin(board, player, plies) {
  const search = new Search();
  const scored = search.rootSearch(board, player, plies);
  if (scored[0].score > WIN_THRESHOLD) return scored[0].m;
  return null;
}
