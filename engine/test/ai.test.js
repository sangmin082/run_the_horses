import { test } from 'node:test';
import assert from 'node:assert/strict';
import { CELLS, CENTER, P1, P2, fromNotation } from '../src/board.js';
import { winningMoves } from '../src/rules.js';
import { bestMove, evaluate, makeRng } from '../src/ai.js';

function emptyBoard() {
  return new Uint8Array(CELLS);
}

function put(board, notation, player) {
  board[fromNotation(notation)] = player;
}

test('AI는 즉시 승리 수를 항상 선택한다', () => {
  const board = emptyBoard();
  put(board, 'e6', P2); // 블로커
  put(board, 'k6', P1); // 슬라이드로 f6 도착 가능
  put(board, 'a1', P1);
  for (const depth of [1, 2, 3]) {
    const move = bestMove(board, P1, { depth, rng: makeRng(0) });
    assert.equal(move.to, CENTER, `depth ${depth}`);
  }
});

test('AI(깊이 2+)는 상대의 즉시 승리를 허용하는 수를 피한다', () => {
  // P2가 다음 수에 승리 가능(k6→f6, 블로커 e6). P1은 이를 막을 수 있다:
  // f8 말이 6열로 슬라이드해 경로에 끼어들거나 자신이 승리 라인을 만든다.
  const board = emptyBoard();
  put(board, 'e6', P1); // 블로커 (양쪽 모두에게 이용 가능)
  put(board, 'k6', P2); // P2의 승리 위협
  put(board, 'h4', P1);
  put(board, 'a1', P1);

  assert.equal(winningMoves(board, P2).length, 1, '전제: P2에게 승리 수가 있다');

  const move = bestMove(board, P1, { depth: 2, rng: makeRng(3) });
  // P1의 수 이후 P2에게 즉시 승리 수가 없어야 한다
  const board2 = Uint8Array.from(board);
  board2[move.to] = board2[move.from] === 0 ? board2[move.to] : board2[move.from];
  board2[move.from] = 0;
  board2[move.to] = P1;
  const p2Wins = winningMoves(board2, P2);
  assert.equal(p2Wins.length, 0, `P1의 수 ${JSON.stringify(move)} 이후에도 P2 승리 가능`);
});

test('평가 함수: 승리 위협이 있는 쪽이 높은 점수를 받는다', () => {
  const board = emptyBoard();
  put(board, 'e6', P2);
  put(board, 'k6', P1); // P1에게 즉시 승리 수
  put(board, 'k1', P2);
  assert.ok(evaluate(board, P1) > evaluate(board, P2));
});

test('시드 RNG는 재현 가능하다', () => {
  const a = makeRng(123);
  const b = makeRng(123);
  for (let i = 0; i < 10; i++) assert.equal(a(), b());
});
