import { test } from 'node:test';
import assert from 'node:assert/strict';
import { P1, P2, CENTER, fromNotation } from '../src/board.js';
import { Match } from '../src/game.js';
import { bestMove, makeRng } from '../src/ai.js';

// AI끼리 한 라운드를 끝까지 진행시키는 헬퍼
function playOutRound(match, rng, plyLimit = 300) {
  for (let ply = 0; ply < plyLimit; ply++) {
    const move = bestMove(match.board, match.turn, { depth: 2, rng });
    assert.ok(move, '합법수가 있어야 한다');
    const result = match.play(move);
    if (result.roundOver) return result;
  }
  assert.fail('라운드가 수 제한 안에 끝나지 않음');
}

test('라운드별 선공 교대: 1·3라운드 P1, 2라운드 P2', () => {
  const match = new Match();
  assert.equal(match.roundNumber, 1);
  assert.equal(match.turn, P1);

  const rng = makeRng(42);
  playOutRound(match, rng);
  if (match.matchWinner === null) {
    match.nextRound();
    assert.equal(match.roundNumber, 2);
    assert.equal(match.turn, P2);
  }
});

test('3판 2선승: 2라운드를 이긴 플레이어가 매치 승리', () => {
  const rng = makeRng(7);
  const match = new Match();
  let guard = 0;
  while (match.matchWinner === null && guard < 3) {
    playOutRound(match, rng);
    if (match.matchWinner === null) match.nextRound();
    guard += 1;
  }
  assert.ok(match.matchWinner === P1 || match.matchWinner === P2);
  assert.equal(match.roundWins[match.matchWinner], 2);
  assert.ok(match.roundNumber <= 3);
});

test('라운드 승리는 오아시스 도착으로만 발생한다', () => {
  const rng = makeRng(99);
  const match = new Match();
  const result = playOutRound(match, rng);
  const lastMove = match.history[match.history.length - 1];
  assert.equal(lastMove.to, CENTER);
  assert.equal(result.winner, lastMove.player);
});

test('종료된 라운드에는 수를 둘 수 없다', () => {
  const rng = makeRng(1);
  const match = new Match();
  playOutRound(match, rng);
  assert.throws(() => match.play({ from: 0, to: 1, kind: 'slide' }));
});
