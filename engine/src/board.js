// 말 달리자 — 보드 정의 (순수 로직, UI 무의존)
//
// 좌표계: 11x11, r(행) 0~10 = 'a'~'k', c(열) 0~10 = 1~11
// 인덱스 idx = r * 11 + c. 정중앙 f6 = (5,5) = idx 60.

export const SIZE = 11;
export const CELLS = SIZE * SIZE;
export const CENTER = 5 * SIZE + 5; // f6, 오아시스

// 칸 종류
export const DESERT = 0; // 사막(노랑)
export const MEADOW = 1; // 초원(초록) — 오아시스를 둘러싼 8칸
export const OASIS = 2;  // 오아시스 — 정중앙 1칸

// 말 (보드 배열 값)
export const EMPTY = 0;
export const P1 = 1; // 선공 기준 플레이어 1
export const P2 = 2;

export function rc(idx) {
  return [Math.floor(idx / SIZE), idx % SIZE];
}

export function idxOf(r, c) {
  return r * SIZE + c;
}

export function inBounds(r, c) {
  return r >= 0 && r < SIZE && c >= 0 && c < SIZE;
}

// 'f6' 같은 표기 <-> 인덱스
export function toNotation(idx) {
  const [r, c] = rc(idx);
  return String.fromCharCode(97 + r) + (c + 1);
}

export function fromNotation(s) {
  const r = s.charCodeAt(0) - 97;
  const c = parseInt(s.slice(1), 10) - 1;
  if (!inBounds(r, c)) throw new Error(`잘못된 좌표: ${s}`);
  return idxOf(r, c);
}

// 칸 종류 조회 — 초원은 중앙에서 맨해튼 거리 2 이내의 12칸 다이아몬드.
// (팬게임 horse-run-game 소스와 교차 검증. docs/competitor-analysis.md 참고)
export function terrainOf(idx) {
  if (idx === CENTER) return OASIS;
  const [r, c] = rc(idx);
  if (Math.abs(r - 5) + Math.abs(c - 5) <= 2) return MEADOW;
  return DESERT;
}

// 초기 배치 — 각 플레이어가 대각 방향으로 마주보는 두 코너에 ㄱ자(브래킷)
// 형태로 5개씩 배치한다. (위키 서술 "각 대각선 위치에서 마주보는 형태로 5개씩"과
// 부합하며, 팬게임 horse-run-game의 배치와 동일. 최종 확정은 원작 영상 대조로.)
// P1(선공): 좌상 코너 + 우하 코너
// P2(후공): 우상 코너 + 좌하 코너
export const INITIAL_P1 = ['a1', 'a2', 'a3', 'b1', 'c1', 'i11', 'j11', 'k11', 'k10', 'k9'];
export const INITIAL_P2 = ['a9', 'a10', 'a11', 'b11', 'c11', 'i1', 'j1', 'k1', 'k2', 'k3'];

// 새 라운드용 보드 배열 생성
export function initialBoard() {
  const board = new Uint8Array(CELLS);
  for (const s of INITIAL_P1) board[fromNotation(s)] = P1;
  for (const s of INITIAL_P2) board[fromNotation(s)] = P2;
  return board;
}

export function opponent(player) {
  return player === P1 ? P2 : P1;
}
