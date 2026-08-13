// 앱 아이콘 생성 — 외부 의존성 없이 zlib로 PNG를 직접 인코딩한다.
// 디자인: 사막 모래 바탕 + 초원 다이아몬드 + 오아시스 + 말(나이트) 실루엣 픽셀아트
// 사용법: node tools/gen-appicon.js
import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const SIZE = 1024;
const px = new Uint8Array(SIZE * SIZE * 3);

function put(x, y, [r, g, b]) {
  const i = (y * SIZE + x) * 3;
  px[i] = r;
  px[i + 1] = g;
  px[i + 2] = b;
}

const SAND = [232, 206, 134];
const SAND_DARK = [222, 193, 116];
const MEADOW = [143, 179, 106];
const OASIS = [59, 147, 165];
const OASIS_LIGHT = [122, 193, 208];
const HORSE = [70, 44, 24];

// 1) 바탕: 은은한 체커 사막
const cellPx = SIZE / 11;
for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    const cr = Math.floor(y / cellPx);
    const cc = Math.floor(x / cellPx);
    put(x, y, (cr + cc) % 2 === 0 ? SAND : SAND_DARK);
  }
}

// 2) 초원 다이아몬드 (중앙 맨해튼 거리 2 이내) + 오아시스 — 보드 그대로
const cx = 5;
const cy = 5;
for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    const cr = Math.floor(y / cellPx);
    const cc = Math.floor(x / cellPx);
    const dist = Math.abs(cr - cy) + Math.abs(cc - cx);
    if (dist === 0) put(x, y, OASIS);
    else if (dist <= 2) put(x, y, MEADOW);
  }
}

// 오아시스 물결 하이라이트
const oasisCenterX = (cx + 0.5) * cellPx;
const oasisCenterY = (cy + 0.38) * cellPx;
for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    const dx = x - oasisCenterX;
    const dy = y - oasisCenterY;
    if (dx * dx + dy * dy < (cellPx * 0.22) ** 2) put(x, y, OASIS_LIGHT);
  }
}

// 3) 말(체스 나이트) 실루엣 — 16×16 픽셀아트를 확대해 좌하단에 배치
const knight = [
  '................',
  '......##........',
  '.....####.#.....',
  '....#######.....',
  '...#########....',
  '..###########...',
  '..####..#####...',
  '.####...#####...',
  '.###....#####...',
  '.##....######...',
  '.#....######....',
  '.....######.....',
  '....#######.....',
  '...#########....',
  '..###########...',
  '..###########...',
];
const scale = 34;
const offsetX = Math.round(SIZE * 0.10);
const offsetY = Math.round(SIZE * 0.36);
for (let r = 0; r < knight.length; r++) {
  for (let c = 0; c < knight[r].length; c++) {
    if (knight[r][c] !== '#') continue;
    for (let dy = 0; dy < scale; dy++) {
      for (let dx = 0; dx < scale; dx++) {
        const x = offsetX + c * scale + dx;
        const y = offsetY + r * scale + dy;
        if (x < SIZE && y < SIZE) put(x, y, HORSE);
      }
    }
  }
}

// 4) PNG 인코딩 (8비트 RGB, 필터 0)
function crc32(buf) {
  let table = crc32.table;
  if (!table) {
    table = crc32.table = new Int32Array(256).map((_, n) => {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      return c;
    });
  }
  let crc = -1;
  for (const byte of buf) crc = (crc >>> 8) ^ table[(crc ^ byte) & 0xff];
  return (crc ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const typeBuf = Buffer.from(type, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])));
  return Buffer.concat([len, typeBuf, data, crc]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8; // 비트 깊이
ihdr[9] = 2; // 컬러 타입: RGB

const raw = Buffer.alloc(SIZE * (SIZE * 3 + 1));
for (let y = 0; y < SIZE; y++) {
  raw[y * (SIZE * 3 + 1)] = 0; // 필터 없음
  px.subarray(y * SIZE * 3, (y + 1) * SIZE * 3)
    .forEach((v, i) => { raw[y * (SIZE * 3 + 1) + 1 + i] = v; });
}

const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk('IHDR', ihdr),
  chunk('IDAT', deflateSync(raw, { level: 9 })),
  chunk('IEND', Buffer.alloc(0)),
]);

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'RunHorses/Assets.xcassets/AppIcon.appiconset/AppIcon.png');
writeFileSync(out, png);
console.log(`AppIcon.png 생성 완료 (${(png.length / 1024).toFixed(0)}KB)`);
