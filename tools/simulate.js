// 선공 밸런스 시뮬레이션 — AI 자가대전으로 단일 라운드의 선공 승률을 측정한다.
// 사용법: node tools/simulate.js [게임수] [깊이] [시드]
import { P1, P2, initialBoard, opponent } from '../engine/src/board.js';
import { applyMove, isWinningMove } from '../engine/src/rules.js';
import { bestMove, makeRng } from '../engine/src/ai.js';

const games = parseInt(process.argv[2] ?? '30', 10);
const depth = parseInt(process.argv[3] ?? '2', 10);
const seed = parseInt(process.argv[4] ?? '2026', 10);
const PLY_LIMIT = 200;

function playRound(rng, randomness) {
  const board = initialBoard();
  let turn = P1; // 선공 고정 — 선공 우위를 측정하는 것이 목적
  for (let ply = 1; ply <= PLY_LIMIT; ply++) {
    const move = bestMove(board, turn, { depth, randomness, rng });
    if (!move) return { winner: null, plies: ply };
    applyMove(board, move);
    if (isWinningMove(move)) return { winner: turn, plies: ply };
    turn = opponent(turn);
  }
  return { winner: null, plies: PLY_LIMIT };
}

const rng = makeRng(seed);
let firstWins = 0;
let secondWins = 0;
let draws = 0;
let totalPlies = 0;
const start = Date.now();

for (let g = 0; g < games; g++) {
  // randomness 2~4를 섞어 다양한 기보 생성 (완전 결정적 반복 방지)
  const randomness = 2 + (g % 3);
  const { winner, plies } = playRound(rng, randomness);
  totalPlies += plies;
  if (winner === P1) firstWins += 1;
  else if (winner === P2) secondWins += 1;
  else draws += 1;
}

const elapsed = ((Date.now() - start) / 1000).toFixed(1);
const pct = (n) => ((n / games) * 100).toFixed(1);

console.log(`## 선공 밸런스 시뮬레이션 결과`);
console.log(`- 설정: ${games}게임, 탐색 깊이 ${depth}, 시드 ${seed}, 수 제한 ${PLY_LIMIT}플라이`);
console.log(`- 선공 승: ${firstWins} (${pct(firstWins)}%)`);
console.log(`- 후공 승: ${secondWins} (${pct(secondWins)}%)`);
console.log(`- 무승부(수 제한): ${draws} (${pct(draws)}%)`);
console.log(`- 평균 게임 길이: ${(totalPlies / games).toFixed(1)}플라이`);
console.log(`- 소요 시간: ${elapsed}초`);
