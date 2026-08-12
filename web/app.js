// 말 달리자 — 웹 프로토타입 UI
import {
  SIZE, CENTER, MEADOW, OASIS, P1, P2, EMPTY, rc, terrainOf, toNotation,
} from '../engine/src/board.js';
import { movesForPiece, SLIDE } from '../engine/src/rules.js';
import { Match } from '../engine/src/game.js';
import { bestMove, DIFFICULTY } from '../engine/src/ai.js';

const boardEl = document.getElementById('board');
const piecesEl = document.getElementById('pieces');
const turnChip = document.getElementById('turn-chip');
const pipsEls = { [P1]: document.getElementById('pips-1'), [P2]: document.getElementById('pips-2') };
const roundLabel = document.getElementById('round-label');
const banner = document.getElementById('banner');
const bannerText = document.getElementById('banner-text');
const bannerBtn = document.getElementById('banner-btn');
const modeSel = document.getElementById('mode');
const diffSel = document.getElementById('difficulty');
const newBtn = document.getElementById('new-match');

let match = new Match();
let selected = null; // 선택된 말 인덱스
let legal = [];      // 선택된 말의 합법수
let lastMove = null;
let aiTimer = null;
let pieceEls = new Map(); // 말 인덱스(현재 위치) -> DOM. 이동 시 키 갱신.

const HORSE = { [P1]: '♞', [P2]: '♘' };

function isAiTurn() {
  return modeSel.value === 'ai'
    && match.turn === P2
    && match.roundWinner === null
    && match.matchWinner === null;
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

// 라운드 시작 시 말 DOM 전체 재생성
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
  for (const cell of cellEls) {
    cell.classList.remove('hint', 'hint-l', 'selected');
  }
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
  roundLabel.textContent = `${match.roundNumber}라운드`;
  for (const p of [P1, P2]) {
    pipsEls[p].querySelectorAll('.pip').forEach((pip, i) => {
      pip.classList.toggle(`won-${p}`, i < match.roundWins[p]);
    });
  }
  const dot = `<span class="dot d${match.turn}"></span>`;
  if (match.matchWinner !== null || match.roundWinner !== null) {
    turnChip.innerHTML = '';
    turnChip.classList.remove('thinking');
  } else if (isAiTurn()) {
    turnChip.classList.add('thinking');
    turnChip.innerHTML = `${dot} AI 생각 중…`;
  } else {
    turnChip.classList.remove('thinking');
    const name = match.turn === P1 ? '밤색 말' : '흰 말';
    const who = modeSel.value === 'ai' ? '내 차례' : `${name} 차례`;
    turnChip.innerHTML = `${dot} ${who}`;
  }
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
  if (modeSel.value === 'ai') return p === P1 ? '나' : 'AI';
  return p === P1 ? '밤색 말' : '흰 말';
}

function doMove(move) {
  const el = pieceEls.get(move.from);
  const result = match.play(move);
  lastMove = move;
  selected = null;
  legal = [];

  // 애니메이션: transform만 갱신
  el.style.transform = pieceTransform(move.to);
  pieceEls.delete(move.from);
  pieceEls.set(move.to, el);

  renderHints();
  renderLastMove();
  renderStatus();

  if (result.matchOver) {
    showBanner(`🏆 ${playerName(result.winner)} 매치 승리!`, '새 매치', startMatch);
  } else if (result.roundOver) {
    showBanner(
      `${playerName(result.winner)} ${match.roundNumber}라운드 승리! (오아시스 도착)`,
      '다음 라운드',
      () => {
        match.nextRound();
        startRoundUi();
      },
    );
  } else {
    scheduleAi();
  }
}

function onCellClick(idx) {
  if (match.roundWinner !== null || match.matchWinner !== null) return;
  if (isAiTurn()) return;

  const v = match.board[idx];
  if (v === match.turn) {
    // 자기 말 선택/재선택
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
    const options = DIFFICULTY[diffSel.value] ?? DIFFICULTY.normal;
    const move = bestMove(match.board, match.turn, options);
    if (move) doMove(move);
  }, 350);
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

newBtn.addEventListener('click', startMatch);
modeSel.addEventListener('change', startMatch);
diffSel.addEventListener('change', () => {
  if (modeSel.value === 'ai') scheduleAi();
});

startMatch();
