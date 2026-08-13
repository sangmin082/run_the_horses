// 말 달리자 — 웹 프로토타입 UI
import {
  SIZE, CENTER, MEADOW, OASIS, P1, P2, EMPTY, rc, terrainOf,
  toNotation, fromNotation, opponent,
} from '../engine/src/board.js';
import { movesForPiece, SLIDE } from '../engine/src/rules.js';
import { Match } from '../engine/src/game.js';
import { bestMove, DIFFICULTY } from '../engine/src/ai.js';
import { PUZZLES } from './puzzles.js';

const boardEl = document.getElementById('board');
const piecesEl = document.getElementById('pieces');
const turnChip = document.getElementById('turn-chip');
const pipsEls = { [P1]: document.getElementById('pips-1'), [P2]: document.getElementById('pips-2') };
const roundLabel = document.getElementById('round-label');
const scoreEl = document.getElementById('score');
const puzzleBar = document.getElementById('puzzle-bar');
const puzzleLabel = document.getElementById('puzzle-label');
const puzzleGoal = document.getElementById('puzzle-goal');
const banner = document.getElementById('banner');
const bannerText = document.getElementById('banner-text');
const bannerBtn = document.getElementById('banner-btn');
const modeSel = document.getElementById('mode');
const diffSel = document.getElementById('difficulty');
const newBtn = document.getElementById('new-match');
const undoBtn = document.getElementById('undo');
const soundBtn = document.getElementById('sound');
const prevPuzzleBtn = document.getElementById('puzzle-prev');
const nextPuzzleBtn = document.getElementById('puzzle-next');

let match = new Match();
let selected = null;
let legal = [];
let lastMove = null;
let aiTimer = null;
let pieceEls = new Map();

// 퍼즐 모드 상태
let puzzleIndex = 0;
let puzzleHuman = P1; // 퍼즐에서 사람이 조작하는 진영
let ownMovesUsed = 0;

// 튜토리얼 정의: 각 단계는 고정 포지션에서 특정 이동을 성공시키면 통과
const TUTORIAL = [
  {
    title: '1단계 · 슬라이드',
    text: '말은 가장자리나 다른 말에 막히기 직전까지 미끄러집니다(중간 정지 불가). k6의 말을 위로 끝까지 — a6까지 — 보내보세요.',
    pieces: [['k6', P1]],
    check: (m) => toNotation(m.from) === 'k6' && toNotation(m.to) === 'a6',
  },
  {
    title: '2단계 · L자 이동',
    text: '나이트처럼 점프하되 비어있는 사막 칸에만 도착할 수 있어요. 초록 초원 칸으로는 L자 이동이 안 됩니다. d5의 말로 L자 이동(◆)을 해보세요.',
    pieces: [['d5', P1]],
    check: (m) => m.kind !== SLIDE,
  },
  {
    title: '3단계 · 오아시스 진입',
    text: '오아시스엔 슬라이드로만 도착할 수 있고, 반대편 인접 칸에 블로커가 있어야 정확히 멈춥니다. e6의 블로커를 이용해 k6의 말을 f6에 세워보세요.',
    pieces: [['k6', P1], ['e6', P2]],
    check: (m) => m.to === CENTER,
  },
];
let tutStep = 0;

const HORSE = { [P1]: '♞', [P2]: '♘' };

// --- 사운드 (WebAudio 미니 신스) ---
let audioCtx = null;
let muted = localStorage.getItem('rth-muted') === '1';

function beep(freq, duration = 0.07, delay = 0, type = 'triangle', gain = 0.12) {
  if (muted) return;
  try {
    audioCtx = audioCtx ?? new (window.AudioContext ?? window.webkitAudioContext)();
    const t = audioCtx.currentTime + delay;
    const osc = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    g.gain.setValueAtTime(gain, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + duration);
    osc.connect(g).connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + duration + 0.02);
  } catch { /* 사운드 실패는 무시 */ }
}

const sfx = {
  slide: () => { beep(320, 0.06); beep(480, 0.06, 0.05); },
  lmove: () => beep(560, 0.08),
  win: () => { beep(523, 0.1); beep(659, 0.1, 0.09); beep(784, 0.18, 0.18); },
  lose: () => { beep(330, 0.12); beep(262, 0.2, 0.11); },
};

function renderSoundBtn() {
  soundBtn.textContent = muted ? '🔇' : '🔊';
  soundBtn.setAttribute('aria-label', muted ? '소리 켜기' : '소리 끄기');
}

soundBtn.addEventListener('click', () => {
  muted = !muted;
  localStorage.setItem('rth-muted', muted ? '1' : '0');
  renderSoundBtn();
});

// --- 퍼즐 진행 저장 ---
function solvedSet() {
  try {
    return new Set(JSON.parse(localStorage.getItem('rth-solved') ?? '[]'));
  } catch {
    return new Set();
  }
}

function markSolved(id) {
  const s = solvedSet();
  s.add(id);
  localStorage.setItem('rth-solved', JSON.stringify([...s]));
}

// --- 모드 헬퍼 ---
function mode() {
  return modeSel.value;
}

function isAiTurn() {
  if (match.roundWinner !== null || match.matchWinner !== null) return false;
  if (mode() === 'ai') return match.turn === P2;
  if (mode() === 'puzzle') return match.turn !== puzzleHuman;
  return false; // 2인 대전·튜토리얼은 AI 없음
}

function aiOptions() {
  if (mode() === 'puzzle') return { depth: 3, randomness: 1 };
  return DIFFICULTY[diffSel.value] ?? DIFFICULTY.normal;
}

// --- 보드 셀 생성 (한 번만) ---
const cellEls = [];
for (let i = 0; i < SIZE * SIZE; i++) {
  const cell = document.createElement('button');
  cell.className = 'cell';
  const t = terrainOf(i);
  if (t === MEADOW) cell.classList.add('meadow');
  else if (t === OASIS) cell.classList.add('oasis');
  else {
    const [r, c] = rc(i);
    if ((r + c) % 2 === 1) cell.classList.add('alt');
  }
  cell.setAttribute('aria-label', toNotation(i));
  cell.addEventListener('click', () => onCellClick(i));
  boardEl.appendChild(cell);
  cellEls.push(cell);
}

function pieceTransform(idx) {
  const [r, c] = rc(idx);
  return `translate(${c * 100}%, ${r * 100}%)`;
}

function buildPieces() {
  piecesEl.innerHTML = '';
  pieceEls = new Map();
  for (let i = 0; i < match.board.length; i++) {
    const v = match.board[i];
    if (v === EMPTY) continue;
    const el = document.createElement('div');
    el.className = `piece p${v}`;
    el.style.transform = pieceTransform(i);
    const glyph = document.createElement('span');
    glyph.textContent = HORSE[v];
    el.appendChild(glyph);
    piecesEl.appendChild(el);
    pieceEls.set(i, el);
  }
}

function clearHints() {
  for (const cell of cellEls) cell.classList.remove('hint', 'hint-l', 'selected');
}

function renderHints() {
  clearHints();
  if (selected === null) return;
  cellEls[selected].classList.add('selected');
  for (const m of legal) {
    cellEls[m.to].classList.add('hint');
    if (m.kind !== SLIDE) cellEls[m.to].classList.add('hint-l');
  }
}

function renderLastMove() {
  for (const cell of cellEls) cell.classList.remove('last-from', 'last-to');
  if (!lastMove) return;
  cellEls[lastMove.from].classList.add('last-from');
  cellEls[lastMove.to].classList.add('last-to');
}

function renderStatus() {
  const puzzle = mode() === 'puzzle';
  const tut = mode() === 'tutorial';
  scoreEl.style.display = puzzle || tut ? 'none' : '';
  puzzleBar.style.display = puzzle || tut ? '' : 'none';
  diffSel.style.display = puzzle || tut ? 'none' : '';
  undoBtn.style.display = puzzle || tut ? 'none' : '';

  if (tut) {
    const s = TUTORIAL[tutStep];
    puzzleLabel.textContent = `${s.title} (${tutStep + 1}/${TUTORIAL.length})`;
    puzzleGoal.textContent = s.text;
  } else if (puzzle) {
    const p = PUZZLES[puzzleIndex];
    const check = solvedSet().has(p.id) ? ' ✓' : '';
    puzzleLabel.textContent = `${p.title}${check} (${puzzleIndex + 1}/${PUZZLES.length})`;
    const left = p.ownMoves - ownMovesUsed;
    puzzleGoal.textContent = `${p.ownMoves}수 안에 오아시스 도착 — 남은 수 ${left}`;
  } else {
    roundLabel.textContent = `${match.roundNumber}라운드`;
    for (const p of [P1, P2]) {
      pipsEls[p].querySelectorAll('.pip').forEach((pip, i) => {
        pip.classList.toggle(`won-${p}`, i < match.roundWins[p]);
      });
    }
  }

  const dot = `<span class="dot d${match.turn}"></span>`;
  if (match.matchWinner !== null || match.roundWinner !== null) {
    turnChip.innerHTML = '';
    turnChip.style.display = 'none';
    turnChip.classList.remove('thinking');
    undoBtn.disabled = true;
    return;
  }
  turnChip.style.display = '';
  if (isAiTurn()) {
    turnChip.classList.add('thinking');
    turnChip.innerHTML = `${dot} AI 생각 중…`;
  } else {
    turnChip.classList.remove('thinking');
    const name = match.turn === P1 ? '밤색 말' : '흰 말';
    const who = mode() === '2p' ? `${name} 차례` : '내 차례';
    turnChip.innerHTML = `${dot} ${who}`;
  }

  // 무르기 가능 여부
  undoBtn.disabled = match.history.length === 0
    || match.roundWinner !== null || isAiTurn();
}

function showBanner(text, btnLabel, onClick) {
  bannerText.textContent = text;
  bannerBtn.textContent = btnLabel;
  bannerBtn.onclick = onClick;
  banner.classList.add('show');
}

function hideBanner() {
  banner.classList.remove('show');
}

function playerName(p) {
  if (mode() === '2p') return p === P1 ? '밤색 말' : '흰 말';
  const human = mode() === 'puzzle' ? puzzleHuman : P1;
  return p === human ? '나' : 'AI';
}

function movePieceEl(move) {
  const el = pieceEls.get(move.from);
  el.style.transform = pieceTransform(move.to);
  pieceEls.delete(move.from);
  pieceEls.set(move.to, el);
}

function onRoundEnd(result) {
  if (mode() === 'puzzle') {
    const p = PUZZLES[puzzleIndex];
    if (result.winner === puzzleHuman && ownMovesUsed <= p.ownMoves) {
      markSolved(p.id);
      sfx.win();
      const last = puzzleIndex === PUZZLES.length - 1;
      showBanner('🎉 퍼즐 성공!', last ? '처음부터' : '다음 퍼즐', () => {
        puzzleIndex = last ? 0 : puzzleIndex + 1;
        startPuzzle();
      });
    } else {
      sfx.lose();
      showBanner('상대가 먼저 도착했어요. 다시 도전!', '다시 시도', startPuzzle);
    }
    return;
  }

  if (result.matchOver) {
    (result.winner === P1 || mode() === '2p' ? sfx.win : sfx.lose)();
    showBanner(`🏆 ${playerName(result.winner)} 매치 승리!`, '새 매치', startMatch);
  } else {
    (result.winner === P1 || mode() === '2p' ? sfx.win : sfx.lose)();
    showBanner(
      `${playerName(result.winner)} ${match.roundNumber}라운드 승리! (오아시스 도착)`,
      '다음 라운드',
      () => {
        match.nextRound();
        startRoundUi();
      },
    );
  }
}

function doMove(move) {
  const mover = match.turn;
  const result = match.play(move);
  lastMove = move;
  selected = null;
  legal = [];

  movePieceEl(move);
  if (!result.roundOver) (move.kind === SLIDE ? sfx.slide : sfx.lmove)();

  if (mode() === 'puzzle' && mover === puzzleHuman) ownMovesUsed += 1;

  renderHints();
  renderLastMove();
  renderStatus();

  if (mode() === 'tutorial') {
    onTutorialMove(move);
    return;
  }

  if (result.roundOver) {
    onRoundEnd(result);
    return;
  }

  // 퍼즐: 허용 수를 다 썼는데 승리하지 못함 → 실패
  if (mode() === 'puzzle' && mover === puzzleHuman
      && ownMovesUsed >= PUZZLES[puzzleIndex].ownMoves) {
    sfx.lose();
    showBanner(`${PUZZLES[puzzleIndex].ownMoves}수 안에 도착하지 못했어요.`, '다시 시도', startPuzzle);
    return;
  }

  scheduleAi();
}

function onCellClick(idx) {
  if (match.roundWinner !== null || match.matchWinner !== null) return;
  if (isAiTurn()) return;

  const v = match.board[idx];
  if (v === match.turn) {
    selected = idx;
    legal = movesForPiece(match.board, idx);
    renderHints();
    return;
  }
  if (selected !== null) {
    const move = legal.find((m) => m.to === idx);
    if (move) {
      doMove(move);
      return;
    }
  }
  selected = null;
  legal = [];
  renderHints();
}

function scheduleAi() {
  if (!isAiTurn()) return;
  renderStatus();
  clearTimeout(aiTimer);
  aiTimer = setTimeout(() => {
    if (!isAiTurn()) return;
    const move = bestMove(match.board, match.turn, aiOptions());
    if (move) doMove(move);
  }, 350);
}

// 무르기: 내 마지막 수(그리고 그 뒤의 AI 응수)를 되돌린다
function undo() {
  if (isAiTurn() || match.roundWinner !== null) return;
  const steps = mode() === '2p' ? 1 : 2;
  for (let i = 0; i < steps; i++) {
    if (!match.undo()) break;
  }
  selected = null;
  legal = [];
  lastMove = match.history.length > 0 ? match.history[match.history.length - 1] : null;
  buildPieces();
  renderHints();
  renderLastMove();
  renderStatus();
}

function startRoundUi() {
  hideBanner();
  selected = null;
  legal = [];
  lastMove = null;
  buildPieces();
  renderHints();
  renderLastMove();
  renderStatus();
  scheduleAi();
}

function startMatch() {
  clearTimeout(aiTimer);
  match = new Match();
  startRoundUi();
}

function onTutorialMove(move) {
  const step = TUTORIAL[tutStep];
  if (step.check(move)) {
    sfx.win();
    if (tutStep === TUTORIAL.length - 1) {
      showBanner('🎓 튜토리얼 완료! 이제 실전이에요.', 'AI와 대전', () => {
        modeSel.value = 'ai';
        startMatch();
      });
    } else {
      showBanner('잘했어요!', '다음 단계', () => {
        tutStep += 1;
        startTutorial();
      });
    }
  } else {
    sfx.lose();
    showBanner('목표와 다르게 움직였어요. 다시 해볼까요?', '다시 시도', startTutorial);
  }
}

function startTutorial() {
  clearTimeout(aiTimer);
  match = new Match();
  match.board.fill(0);
  for (const [pos, player] of TUTORIAL[tutStep].pieces) {
    match.board[fromNotation(pos)] = player;
  }
  match.turn = P1;
  startRoundUi();
}

function startPuzzle() {
  clearTimeout(aiTimer);
  const p = PUZZLES[puzzleIndex];
  match = new Match();
  for (let i = 0; i < match.board.length; i++) {
    match.board[i] = Number(p.board[i]);
  }
  match.turn = p.toMove;
  puzzleHuman = p.toMove;
  ownMovesUsed = 0;
  startRoundUi();
}

function startCurrentMode() {
  if (mode() === 'puzzle') startPuzzle();
  else if (mode() === 'tutorial') { tutStep = 0; startTutorial(); }
  else startMatch();
}

newBtn.addEventListener('click', startCurrentMode);
modeSel.addEventListener('change', startCurrentMode);
diffSel.addEventListener('change', () => {
  if (mode() === 'ai') scheduleAi();
});
undoBtn.addEventListener('click', undo);
prevPuzzleBtn.addEventListener('click', () => {
  if (mode() === 'tutorial') {
    tutStep = (tutStep - 1 + TUTORIAL.length) % TUTORIAL.length;
    startTutorial();
    return;
  }
  puzzleIndex = (puzzleIndex - 1 + PUZZLES.length) % PUZZLES.length;
  startPuzzle();
});
nextPuzzleBtn.addEventListener('click', () => {
  if (mode() === 'tutorial') {
    tutStep = (tutStep + 1) % TUTORIAL.length;
    startTutorial();
    return;
  }
  puzzleIndex = (puzzleIndex + 1) % PUZZLES.length;
  startPuzzle();
});

renderSoundBtn();
startCurrentMode();
