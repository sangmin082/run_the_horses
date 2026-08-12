// 말 달리자 — 이동 규칙 (합법수 생성 / 적용 / 승리 판정)
import {
  SIZE, CENTER, DESERT, EMPTY, rc, idxOf, inBounds, terrainOf, opponent,
} from './board.js';

// 슬라이드 방향: 상, 하, 좌, 우
const SLIDE_DIRS = [[-1, 0], [1, 0], [0, -1], [0, 1]];

// L자 이동(나이트) 오프셋 — 한 칸 전진 후 대각선 한 칸 = 변위 (±1,±2)/(±2,±1)
const KNIGHT_OFFSETS = [
  [-2, -1], [-2, 1], [-1, -2], [-1, 2],
  [1, -2], [1, 2], [2, -1], [2, 1],
];

export const SLIDE = 'slide';
export const LMOVE = 'lmove';

// 특정 말(from)의 합법수 목록. 이동은 {from, to, kind}.
export function movesForPiece(board, from) {
  const moves = [];
  const [r, c] = rc(from);

  // 슬라이드: 가장자리나 다른 말에 막히기 직전까지 직선 이동 (중간 정지 불가)
  for (const [dr, dc] of SLIDE_DIRS) {
    let nr = r + dr;
    let nc = c + dc;
    let last = -1;
    while (inBounds(nr, nc) && board[idxOf(nr, nc)] === EMPTY) {
      last = idxOf(nr, nc);
      nr += dr;
      nc += dc;
    }
    if (last !== -1) moves.push({ from, to: last, kind: SLIDE });
  }

  // L자: 나이트처럼 점프. 도착 칸이 "비어있는 사막 칸"일 때만 가능
  for (const [dr, dc] of KNIGHT_OFFSETS) {
    const nr = r + dr;
    const nc = c + dc;
    if (!inBounds(nr, nc)) continue;
    const to = idxOf(nr, nc);
    if (board[to] === EMPTY && terrainOf(to) === DESERT) {
      moves.push({ from, to, kind: LMOVE });
    }
  }

  return moves;
}

// player의 전체 합법수
export function legalMoves(board, player) {
  const moves = [];
  for (let i = 0; i < board.length; i++) {
    if (board[i] === player) moves.push(...movesForPiece(board, i));
  }
  return moves;
}

// 이동 적용 (board를 제자리 수정). 되돌리기용으로 from/to를 반환.
export function applyMove(board, move) {
  board[move.to] = board[move.from];
  board[move.from] = EMPTY;
}

export function undoMove(board, move) {
  board[move.from] = board[move.to];
  board[move.to] = EMPTY;
}

// 이동 직후 라운드 승리 여부: 오아시스 도착이 유일한 승리 조건
export function isWinningMove(move) {
  return move.to === CENTER;
}

// player가 이번 수로 즉시 승리할 수 있는 이동 목록
export function winningMoves(board, player) {
  return legalMoves(board, player).filter(isWinningMove);
}
