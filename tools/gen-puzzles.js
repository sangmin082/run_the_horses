// 퍼즐 생성기 — AI 자가대전 기보에서 퍼즐 포지션을 추출해 web/puzzles.js를 생성한다.
//   1수 퍼즐: 즉시 승리 수가 정확히 1개 존재
//   2수 퍼즐: 즉시 승리는 없지만 3플라이(내-상대-내) 강제승 존재, 첫 수가 유일
// 사용법: node tools/gen-puzzles.js [시드]
import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { P1, P2, initialBoard, opponent } from '../engine/src/board.js';
import { applyMove, isWinningMove, winningMoves } from '../engine/src/rules.js';
import { bestMove, forcedWin, searchScore, hashBoard, makeRng } from '../engine/src/ai.js';

const seed = parseInt(process.argv[2] ?? '511', 10);
const WANT_ONE = 4;   // 1수 퍼즐 개수
const WANT_TWO = 8;   // 2수 퍼즐 개수
const WIN_THRESHOLD = 90000;

const rng = makeRng(seed);
const seen = new Set();
const oneMovers = [];
const twoMovers = [];

// 3플라이 강제승의 첫 수가 유일한지 확인 (풀이가 깔끔한 퍼즐만 채택)
function uniqueForcedFirstMoves(board, player) {
  const { legalMoves } = rulesModule;
  let count = 0;
  for (const m of legalMoves(board, player)) {
    if (isWinningMove(m)) return 99; // 즉시 승리가 있으면 2수 퍼즐 아님
    applyMove(board, m);
    // 상대의 모든 응수에 대해 내가 즉시 승리 가능해야 강제승
    const opp = opponent(player);
    const replies = legalMoves(board, opp);
    let forced = replies.length > 0;
    for (const r of replies) {
      applyMove(board, r);
      const winsAfter = winningMoves(board, player);
      applyUndo(board, r);
      if (winsAfter.length === 0) { forced = false; break; }
    }
    applyUndo(board, m);
    if (forced) count += 1;
    if (count > 1) return count;
  }
  return count;
}

function applyUndo(board, move) {
  board[move.from] = board[move.to];
  board[move.to] = 0;
}

let rulesModule;

// 게임당 각 유형 1개씩만 추출해 퍼즐 간 다양성을 확보한다
function record(board, toMove, perGame) {
  const key = hashBoard(board, toMove);
  if (seen.has(key)) return;

  const wins = winningMoves(board, toMove);
  if (wins.length === 1 && oneMovers.length < WANT_ONE && !perGame.one) {
    seen.add(key);
    perGame.one = true;
    oneMovers.push({ board: Array.from(board).join(''), toMove, ownMoves: 1 });
    return;
  }
  if (wins.length === 0 && twoMovers.length < WANT_TWO && !perGame.two) {
    if (forcedWin(board, toMove, 3) && uniqueForcedFirstMoves(board, toMove) === 1) {
      seen.add(key);
      perGame.two = true;
      twoMovers.push({ board: Array.from(board).join(''), toMove, ownMoves: 2 });
    }
  }
}

const main = async () => {
  rulesModule = await import('../engine/src/rules.js');

  let game = 0;
  while ((oneMovers.length < WANT_ONE || twoMovers.length < WANT_TWO) && game < 200) {
    game += 1;
    const board = initialBoard();
    let turn = P1;
    const perGame = { one: false, two: false };
    for (let ply = 1; ply <= 120; ply++) {
      if (ply >= 5) record(board, turn, perGame); // 초반 몇 수는 건너뛴다 (배치가 비슷해 중복됨)
      const move = bestMove(board, turn, { depth: 2, randomness: 2 + (game % 3), rng });
      if (!move) break;
      applyMove(board, move);
      if (isWinningMove(move)) break;
      turn = opponent(turn);
    }
  }

  const puzzles = [
    ...oneMovers.map((p, i) => ({ id: `e${i + 1}`, title: `연습 ${i + 1}`, ...p })),
    ...twoMovers.map((p, i) => ({ id: `p${i + 1}`, title: `퍼즐 ${i + 1}`, ...p })),
  ];

  const root = join(dirname(fileURLToPath(import.meta.url)), '..');
  const out = `// 자동 생성 파일 — tools/gen-puzzles.js (시드 ${seed}). 직접 수정하지 말 것.
// board: 121글자(0=빈칸, 1=밤색 말, 2=흰 말), toMove: 둘 차례, ownMoves: 허용되는 내 수
export const PUZZLES = ${JSON.stringify(puzzles, null, 2)};
`;
  writeFileSync(join(root, 'web/puzzles.js'), out);
  console.log(`1수 퍼즐 ${oneMovers.length}개, 2수 퍼즐 ${twoMovers.length}개 → web/puzzles.js (자가대전 ${game}게임 탐색)`);
};

main();
