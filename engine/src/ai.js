// 말 달리자 — AI (평가 함수 + 네가맥스 알파-베타)
import {
  SIZE, CENTER, EMPTY, P1, P2, rc, idxOf, inBounds, opponent,
} from './board.js';
import { legalMoves, applyMove, undoMove, isWinningMove } from './rules.js';

const WIN_SCORE = 100000;

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

// 오아시스 진입 가능성 스캔.
// 각 방향에서 중앙에 가장 가까운 말을 찾아, 그 말이 슬라이드로 오아시스에
// "정확히 멈출 수 있는지"(반대편 인접 칸에 블로커 존재 + 경로 깨끗)를 판정한다.
// wins: 즉시 승리 가능 수의 수, near: 블로커만 생기면 승리하는 잠재 위협 수
function scanCenterLines(board) {
  const result = {
    [P1]: { wins: 0, near: 0 },
    [P2]: { wins: 0, near: 0 },
  };
  const [cr, cc] = rc(CENTER);
  const dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];

  for (const [dr, dc] of dirs) {
    // 방향 (dr,dc) 쪽으로 스캔해 첫 말을 찾는다
    let r = cr + dr;
    let c = cc + dc;
    let piece = EMPTY;
    while (inBounds(r, c)) {
      const v = board[idxOf(r, c)];
      if (v !== EMPTY) { piece = v; break; }
      r += dr;
      c += dc;
    }
    if (piece === EMPTY) continue;

    // 그 말이 중앙으로 미끄러질 때 멈춰줄 블로커: 반대편 인접 칸
    const br = cr - dr;
    const bc = cc - dc;
    const blocked = inBounds(br, bc) && board[idxOf(br, bc)] !== EMPTY;
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

  for (let i = 0; i < board.length; i++) {
    const v = board[i];
    if (v === EMPTY) continue;
    const sign = v === player ? 1 : -1;
    const [r, c] = rc(i);
    const dist = Math.abs(r - 5) + Math.abs(c - 5);
    score += sign * (10 - dist) * 3; // 중앙 접근
    if (r === 5 || c === 5) score += sign * 6; // 중앙 라인 점유
  }
  return score;
}

// 이동 정렬: 승리 수 → 중앙에 가까워지는 수 순
function orderMoves(moves) {
  return moves
    .map((m) => {
      if (isWinningMove(m)) return { m, key: 1e9 };
      const [r, c] = rc(m.to);
      const [fr, fc] = rc(m.from);
      const dTo = Math.abs(r - 5) + Math.abs(c - 5);
      const dFrom = Math.abs(fr - 5) + Math.abs(fc - 5);
      let key = (dFrom - dTo) * 10;
      if (r === 5 || c === 5) key += 5;
      return { m, key };
    })
    .sort((a, b) => b.key - a.key)
    .map((x) => x.m);
}

// 네가맥스 + 알파-베타. toMove 관점 점수를 반환.
function negamax(board, depth, alpha, beta, toMove, ply) {
  const moves = legalMoves(board, toMove);
  if (moves.length === 0) return 0; // 이동 불가 = 무승부 취급 (실전에선 거의 불가능)

  // 즉시 승리 수가 있으면 탐색 없이 확정
  for (const m of moves) {
    if (isWinningMove(m)) return WIN_SCORE - ply;
  }
  if (depth === 0) return evaluate(board, toMove);

  let best = -Infinity;
  for (const m of orderMoves(moves)) {
    applyMove(board, m);
    const score = -negamax(board, depth - 1, -beta, -alpha, opponent(toMove), ply + 1);
    undoMove(board, m);
    if (score > best) best = score;
    if (best > alpha) alpha = best;
    if (alpha >= beta) break;
  }
  return best;
}

// 난이도 프리셋
export const DIFFICULTY = {
  easy: { depth: 1, randomness: 3 },   // 상위 3개 수 중 무작위
  normal: { depth: 2, randomness: 1 },
  hard: { depth: 3, randomness: 1 }, // 깊이 4는 수당 ~0.6초(Node 기준)라 모바일 웹에선 3이 상한

};

// 최선 수 선택. options: { depth, randomness, rng }
export function bestMove(board, player, options = {}) {
  const depth = options.depth ?? 2;
  const randomness = options.randomness ?? 1;
  const rng = options.rng ?? Math.random;

  const moves = legalMoves(board, player);
  if (moves.length === 0) return null;

  // 즉시 승리는 바로 선택
  const win = moves.find(isWinningMove);
  if (win) return win;

  const scored = [];
  let alpha = -Infinity;
  for (const m of orderMoves(moves)) {
    applyMove(board, m);
    const score = -negamax(board, depth - 1, -Infinity, -alpha, opponent(player), 1);
    undoMove(board, m);
    scored.push({ m, score });
    if (score > alpha) alpha = score;
  }
  scored.sort((a, b) => b.score - a.score);

  // 동점(또는 randomness 상위권) 내에서 무작위 선택
  const pool = scored.filter(
    (s, i) => i < randomness || s.score === scored[0].score,
  );
  return pool[Math.floor(rng() * pool.length)].m;
}
