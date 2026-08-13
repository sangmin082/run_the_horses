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

test('초원은 중앙 맨해튼 거리 2 이내의 12칸, 나머지는 사막', () => {
  const meadow = ['d6', 'e5', 'e6', 'e7', 'f4', 'f5', 'f7', 'f8', 'g5', 'g6', 'g7', 'h6'];
  for (const s of meadow) assert.equal(terrainOf(fromNotation(s)), MEADOW, s);
  let meadowCount = 0;
  for (let i = 0; i < CELLS; i++) if (terrainOf(i) === MEADOW) meadowCount += 1;
  assert.equal(meadowCount, 12);
  for (const s of ['a1', 'f1', 'd5', 'e4', 'c6', 'f9', 'k11']) {
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
