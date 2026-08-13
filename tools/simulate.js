// 선공 밸런스 시뮬레이션 — AI 자가대전으로 단일 라운드의 선공 승률을 측정한다.
//
// 사용법: node tools/simulate.js [게임수] [강도] [시드] [변형]
//   강도: 숫자 = 고정 탐색 깊이, "t300" = 수당 300ms 반복 심화
//   변형: none(기본) | pie — 파이 룰: 선공의 첫 수를 본 후 후공이 유리하다고
//         판단하면 진영을 교체한다(교체 판단도 AI 탐색으로).
import { P1, P2, initialBoard, opponent } from '../engine/src/board.js';
import { applyMove, isWinningMove } from '../engine/src/rules.js';
import { bestMove, forcedWin, searchScore, makeRng } from '../engine/src/ai.js';

const games = parseInt(process.argv[2] ?? '30', 10);
const strengthArg = process.argv[3] ?? '2';
const seed = parseInt(process.argv[4] ?? '2026', 10);
const variant = process.argv[5] ?? 'none';
const PLY_LIMIT = 200;

const strength = strengthArg.startsWith('t')
  ? { timeMs: parseInt(strengthArg.slice(1), 10), maxDepth: 9 }
  : { depth: parseInt(strengthArg, 10) };

// 파이 룰 교체 판단: 선공의 첫 수 이후 포지션을 후공 관점에서 평가.
// 강제승 라인이 보이거나 평가가 크게 불리하면 진영을 교체한다.
function pieSwapDecision(board) {
  if (forcedWin(board, P1, 3)) return true; // 선공(수를 둔 쪽)에게 3플라이 강제승이 남음
  return searchScore(board, P2, 4) < -150; // 후공 관점 탐색 점수가 크게 불리하면 교체
}

function playRound(rng, randomness) {
  const board = initialBoard();
  let turn = P1;
  let swapped = false;
  for (let ply = 1; ply <= PLY_LIMIT; ply++) {
    const move = bestMove(board, turn, { ...strength, randomness, rng });
    if (!move) return { winner: null, plies: ply, swapped };
    applyMove(board, move);
    if (isWinningMove(move)) {
      // 파이 룰로 교체됐다면 "선공 진영"의 승리는 후공 플레이어의 승리다
      let winner = turn;
      if (swapped) winner = opponent(winner);
      return { winner, plies: ply, swapped };
    }
    if (variant === 'pie' && ply === 1) {
      swapped = pieSwapDecision(board);
    }
    turn = opponent(turn);
  }
  return { winner: null, plies: PLY_LIMIT, swapped };
}

const rng = makeRng(seed);
let firstWins = 0;
let secondWins = 0;
let draws = 0;
let swaps = 0;
let totalPlies = 0;
const start = Date.now();

for (let g = 0; g < games; g++) {
  const randomness = 2 + (g % 3); // 기보 다양화
  const { winner, plies, swapped } = playRound(rng, randomness);
  totalPlies += plies;
  if (swapped) swaps += 1;
  if (winner === P1) firstWins += 1;
  else if (winner === P2) secondWins += 1;
  else draws += 1;
}

const elapsed = ((Date.now() - start) / 1000).toFixed(1);
const pct = (n) => ((n / games) * 100).toFixed(1);

console.log(`## 선공 밸런스 시뮬레이션 결과`);
console.log(`- 설정: ${games}게임, 강도 ${strengthArg}, 시드 ${seed}, 변형 ${variant}, 수 제한 ${PLY_LIMIT}플라이`);
console.log(`- 선공 승: ${firstWins} (${pct(firstWins)}%)`);
console.log(`- 후공 승: ${secondWins} (${pct(secondWins)}%)`);
console.log(`- 무승부(수 제한): ${draws} (${pct(draws)}%)`);
if (variant === 'pie') console.log(`- 진영 교체 발생: ${swaps} (${pct(swaps)}%)`);
console.log(`- 평균 게임 길이: ${(totalPlies / games).toFixed(1)}플라이`);
console.log(`- 소요 시간: ${elapsed}초`);
