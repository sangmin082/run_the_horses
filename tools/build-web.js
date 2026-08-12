// web/ 개발 소스를 단일 HTML 파일(web/dist/index.html)로 번들한다.
// 외부 요청이 차단된 환경(아티팩트 등)에서도 동작하도록 CSS/JS를 전부 인라인.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

// ESM 소스에서 import 문과 export 키워드를 제거해 이어붙일 수 있게 만든다.
function stripEsm(source) {
  return source
    .replace(/^import[\s\S]*?from\s+['"][^'"]+['"];\s*$/gm, '')
    .replace(/^export\s+/gm, '');
}

const engineFiles = ['board.js', 'rules.js', 'game.js', 'ai.js'];
const engineCode = engineFiles
  .map((f) => `// ===== engine/src/${f} =====\n${stripEsm(readFileSync(join(root, 'engine/src', f), 'utf8'))}`)
  .join('\n');

const appCode = stripEsm(readFileSync(join(root, 'web/app.js'), 'utf8'));
const css = readFileSync(join(root, 'web/style.css'), 'utf8');
const html = readFileSync(join(root, 'web/index.html'), 'utf8');

const bundled = html
  .replace('<link rel="stylesheet" href="style.css">', `<style>\n${css}</style>`)
  .replace(
    '<script type="module" src="app.js"></script>',
    `<script>\n"use strict";\n${engineCode}\n// ===== web/app.js =====\n${appCode}</script>`,
  );

if (bundled.includes('style.css') || bundled.includes('app.js"')) {
  throw new Error('번들 치환 실패: 원본 참조가 남아 있음');
}

mkdirSync(join(root, 'web/dist'), { recursive: true });
writeFileSync(join(root, 'web/dist/index.html'), bundled);
console.log(`web/dist/index.html 생성 완료 (${(bundled.length / 1024).toFixed(1)}KB)`);
