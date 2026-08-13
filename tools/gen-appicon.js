// 앱 아이콘 생성 — tools/appicon.html을 Chromium으로 1024×1024 캡처한다.
// 요구사항: playwright + Chromium (개발 환경 전용 도구, 앱 빌드에는 불필요)
//   npx playwright install chromium  (또는 PLAYWRIGHT_BROWSERS_PATH의 기존 설치 사용)
// 사용법: node tools/gen-appicon.js [playwright모듈경로]
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(import.meta.url);
const playwrightPath = process.argv[2] ?? 'playwright';
const { chromium } = require(playwrightPath);

const executablePath = process.env.CHROMIUM_PATH; // 미지정 시 playwright 기본 탐색

const browser = await chromium.launch(executablePath ? { executablePath } : {});
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
await page.goto(`file://${join(root, 'tools/appicon.html')}`);
await page.waitForTimeout(300); // 폰트 로드 대기
const out = join(root, 'RunHorses/Assets.xcassets/AppIcon.appiconset/AppIcon.png');
await page.screenshot({ path: out });
await browser.close();
console.log(`AppIcon.png 생성 완료 → ${out}`);
