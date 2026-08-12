import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  CELLS, CENTER, DESERT, MEADOW, OASIS, P1, P2, EMPTY,
  terrainOf, toNotation, fromNotation, initialBoard,
} from '../src/board.js';

test('정중앙 f6은 오아시스', () => {
  assert.equal(fromNotation('f6'), CENTER);
  assert.equal(terrainOf(CENTER), OASIS);
});

test('오아시스 주변 8칸은 초원, 나머지는 사막', () => {
  const meadow = ['e5', 'e6', 'e7', 'f5', 'f7', 'g5', 'g6', 'g7'];
  for (const s of meadow) assert.equal(terrainOf(fromNotation(s)), MEADOW, s);
  for (const s of ['a1', 'f1', 'd6', 'f8', 'k11', 'h6']) {
    assert.equal(terrainOf(fromNotation(s)), DESERT, s);
  }
});

test('좌표 표기 왕복 변환', () => {
  for (let i = 0; i < CELLS; i++) {
    assert.equal(fromNotation(toNotation(i)), i);
  }
  assert.equal(toNotation(0), 'a1');
  assert.equal(toNotation(CELLS - 1), 'k11');
});

test('초기 배치: 각 플레이어 10개, 총 20개, 오아시스는 비어있음', () => {
  const board = initialBoard();
  let p1 = 0;
  let p2 = 0;
  for (const v of board) {
    if (v === P1) p1 += 1;
    else if (v === P2) p2 += 1;
  }
  assert.equal(p1, 10);
  assert.equal(p2, 10);
  assert.equal(board[CENTER], EMPTY);
});
