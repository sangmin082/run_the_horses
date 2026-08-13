import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CELLS, CENTER, P1, P2, fromNotation, initialBoard } from '../src/board.js';
import { legalMoves } from '../src/rules.js';
import { bestMove, forcedWin, hashBoard, makeRng } from '../src/ai.js';
import { Match } from '../src/game.js';

function emptyBoard() {
  return new Uint8Array(CELLS);
}

function put(board, notation, player) {
  board[fromNotation(notation)] = player;
}

test('시간제한 탐색: 초기 배치에서 합법수를 반환하고 예산을 크게 넘지 않는다', () => {
  const board = initialBoard();
  const start = Date.now();
  const move = bestMove(board, P1, { timeMs: 300, maxDepth: 9, rng: makeRng(1) });
  const elapsed = Date.now() - start;
  assert.ok(move);
  const legal = legalMoves(board, P1);
  assert.ok(legal.some((m) => m.from === move.from && m.to === move.to));
  // 병렬 테스트 실행 시 CPU 경합이 있으므로 여유 있게: 무한 탐색 방지 확인이 목적
  assert.ok(elapsed < 5000, `소요 ${elapsed}ms`);
});

test('시간제한 탐색: 즉시 승리 수를 선택한다', () => {
  const board = emptyBoard();
  put(board, 'e6', P2);
  put(board, 'k6', P1);
  const move = bestMove(board, P1, { timeMs: 200, rng: makeRng(2) });
  assert.equal(move.to, CENTER);
});

test('forcedWin: 3플라이 강제승 포지션을 찾는다', () => {
  // e2가 동쪽으로 슬라이드하면 e7에 막혀 e6(오아시스 북쪽 인접)에 정지 = 블로커 완성.
  // 다음 P1 차례에 k6이 6열을 따라 북쪽으로 슬라이드해 f6에 정확히 멈춘다.
  // P2(k10, k11)는 한 수로 6열 경로에 끼어들 수 없다.
  const board = emptyBoard();
  put(board, 'e2', P1);
  put(board, 'e7', P1);
  put(board, 'k6', P1);
  put(board, 'k11', P2);
  put(board, 'k10', P2);
  assert.equal(forcedWin(board, P1, 1), null, '즉시 승리는 아직 없어야 한다');
  const win = forcedWin(board, P1, 3);
  assert.ok(win, '강제승이 존재해야 한다');
  assert.equal(win.from, fromNotation('e2'));
  assert.equal(win.to, fromNotation('e6'));
});

test('회귀: 시간 초과로 탐색이 중단되어도 보드가 오염되지 않는다', () => {
  const board = initialBoard();
  const before = Array.from(board);
  // 아주 작은 시간 예산으로 깊은 탐색을 강제 중단시킨다 (여러 번 반복)
  for (let i = 0; i < 20; i++) {
    const move = bestMove(board, P1, { timeMs: 1, maxDepth: 9, rng: makeRng(i) });
    assert.ok(move);
    assert.deepEqual(Array.from(board), before, `${i}번째 호출 후 보드 변형됨`);
  }
});

test('forcedWin: 강제승이 없으면 null', () => {
  const board = emptyBoard();
  put(board, 'a1', P1);
  put(board, 'k11', P2);
  assert.equal(forcedWin(board, P1, 3), null);
});

test('조브리스트 해시: 이동 후 되돌리면 해시가 복원된다', () => {
  const board = initialBoard();
  const h0 = hashBoard(board, P1);
  const move = legalMoves(board, P1)[0];
  board[move.to] = board[move.from];
  board[move.from] = 0;
  const h1 = hashBoard(board, P2);
  assert.notEqual(h0, h1);
  board[move.from] = board[move.to];
  board[move.to] = 0;
  assert.equal(hashBoard(board, P1), h0);
});

test('Match.undo: 수를 되돌리면 차례와 보드가 복원된다', () => {
  const match = new Match();
  const before = Uint8Array.from(match.board);
  const move = match.legalMoves()[0];
  match.play(move);
  assert.equal(match.turn, P2);
  assert.ok(match.undo());
  assert.equal(match.turn, P1);
  assert.deepEqual(Array.from(match.board), Array.from(before));
  assert.equal(match.history.length, 0);
  assert.equal(match.undo(), false); // 더 무를 수 없음
});

test('Match.undo: 승리 수를 무르면 라운드 결과도 되돌아간다', () => {
  const match = new Match();
  // 인위적으로 승리 직전 상태 구성: 보드를 비우고 P1 승리 수 배치
  match.board.fill(0);
  put(match.board, 'e6', P2);
  put(match.board, 'k6', P1);
  const win = match.legalMoves().find((m) => m.to === CENTER);
  const result = match.play(win);
  assert.equal(result.roundOver, true);
  assert.equal(match.roundWins[P1], 1);
  assert.ok(match.undo());
  assert.equal(match.roundWinner, null);
  assert.equal(match.roundWins[P1], 0);
  assert.equal(match.turn, P1);
});
