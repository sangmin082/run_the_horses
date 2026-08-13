import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CELLS, CENTER, P1, P2, fromNotation, toNotation,
} from '../src/board.js';
import {
  SLIDE, LMOVE, movesForPiece, legalMoves, applyMove, undoMove,
  isWinningMove, winningMoves,
} from '../src/rules.js';

function emptyBoard() {
  return new Uint8Array(CELLS);
}

function put(board, notation, player) {
  board[fromNotation(notation)] = player;
}

function movesTo(moves, notation, kind = null) {
  const to = fromNotation(notation);
  return moves.filter((m) => m.to === to && (kind === null || m.kind === kind));
}

test('슬라이드: 빈 보드에서 가장자리까지 미끄러진다', () => {
  const board = emptyBoard();
  put(board, 'c3', P1);
  const slides = movesForPiece(board, fromNotation('c3')).filter((m) => m.kind === SLIDE);
  const dests = slides.map((m) => toNotation(m.to)).sort();
  // 상: a3, 하: k3, 좌: c1, 우: c11
  assert.deepEqual(dests, ['a3', 'c1', 'c11', 'k3'].sort());
});

test('슬라이드: 다른 말에 막히기 직전 칸에 멈춘다', () => {
  const board = emptyBoard();
  put(board, 'c3', P1);
  put(board, 'c8', P2); // 우측 이동을 가로막음
  const slides = movesForPiece(board, fromNotation('c3')).filter((m) => m.kind === SLIDE);
  assert.equal(movesTo(slides, 'c7').length, 1); // c8 직전에 정지
  assert.equal(movesTo(slides, 'c8').length, 0);
  assert.equal(movesTo(slides, 'c11').length, 0);
});

test('슬라이드: 바로 옆이 막혀 있으면 그 방향으로는 이동 불가', () => {
  const board = emptyBoard();
  put(board, 'a1', P1);
  put(board, 'a2', P2);
  put(board, 'b1', P2);
  const moves = movesForPiece(board, fromNotation('a1')).filter((m) => m.kind === SLIDE);
  assert.equal(moves.length, 0);
});

test('L자 이동: 나이트 오프셋, 비어있는 사막 칸만 허용', () => {
  const board = emptyBoard();
  put(board, 'c3', P1); // (2,2) — 도착지 8칸 모두 보드 안의 사막
  const lmoves = movesForPiece(board, fromNotation('c3')).filter((m) => m.kind === LMOVE);
  assert.equal(lmoves.length, 8);
});

test('L자 이동: 초원/오아시스 칸에는 도착 불가', () => {
  const board = emptyBoard();
  put(board, 'd5', P1); // (3,4): 나이트 도착지에 f6(오아시스), e7·f4(초원) 포함
  const lmoves = movesForPiece(board, fromNotation('d5')).filter((m) => m.kind === LMOVE);
  assert.equal(movesTo(lmoves, 'f6').length, 0); // 오아시스 도착 불가
  assert.equal(movesTo(lmoves, 'e7').length, 0); // 초원 도착 불가
  assert.equal(movesTo(lmoves, 'f4').length, 0); // 초원 도착 불가
  assert.equal(movesTo(lmoves, 'b4').length, 1); // 사막은 가능
  assert.equal(movesTo(lmoves, 'c3').length, 1); // 사막은 가능
});

test('L자 이동: 중간에 말이 있어도 점프한다', () => {
  const board = emptyBoard();
  put(board, 'a1', P1);
  put(board, 'a2', P2);
  put(board, 'b1', P2);
  put(board, 'b2', P2); // a1을 완전히 포위해도
  const lmoves = movesForPiece(board, fromNotation('a1')).filter((m) => m.kind === LMOVE);
  const dests = lmoves.map((m) => toNotation(m.to)).sort();
  assert.deepEqual(dests, ['b3', 'c2'].sort()); // 나이트 점프는 가능
});

test('승리 패턴(위키): e6에 블로커가 있으면 같은 열의 말이 f6에 정확히 멈춘다', () => {
  const board = emptyBoard();
  put(board, 'e6', P2); // 블로커 (누구의 말이든 상관없음)
  put(board, 'k6', P1); // 6열 아래쪽, 경로 깨끗
  const wins = winningMoves(board, P1);
  assert.equal(wins.length, 1);
  assert.equal(wins[0].to, CENTER);
  assert.equal(wins[0].kind, SLIDE);
  assert.ok(isWinningMove(wins[0]));
});

test('블로커가 없으면 오아시스를 지나쳐 미끄러진다', () => {
  const board = emptyBoard();
  put(board, 'k6', P1); // 6열에 다른 말 없음
  const slides = movesForPiece(board, fromNotation('k6')).filter((m) => m.kind === SLIDE);
  assert.equal(movesTo(slides, 'f6').length, 0);
  assert.equal(movesTo(slides, 'a6').length, 1); // 반대편 끝까지
  assert.equal(winningMoves(board, P1).length, 0);
});

test('applyMove / undoMove 왕복', () => {
  const board = emptyBoard();
  put(board, 'c3', P1);
  const before = Uint8Array.from(board);
  const move = movesForPiece(board, fromNotation('c3'))[0];
  applyMove(board, move);
  assert.notDeepEqual(Array.from(board), Array.from(before));
  undoMove(board, move);
  assert.deepEqual(Array.from(board), Array.from(before));
});

test('초기 배치에서 양측 모두 합법수가 존재하고 즉시 승리 수는 없다', async () => {
  const { initialBoard } = await import('../src/board.js');
  const board = initialBoard();
  assert.ok(legalMoves(board, P1).length > 0);
  assert.ok(legalMoves(board, P2).length > 0);
  assert.equal(winningMoves(board, P1).length, 0);
  assert.equal(winningMoves(board, P2).length, 0);
});
