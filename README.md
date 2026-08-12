# run_the_horses

데스게임 7회차 <말 달리자>를 모바일(앱스토어) 게임으로 만드는 프로젝트.

- 개발 계획: [PLAN.md](PLAN.md)
- 밸런스 실험: [docs/balance-report.md](docs/balance-report.md)

## 구성

```
engine/src/   룰 엔진 + AI (의존성 없는 순수 JS, ESM) — 이후 Dart/네이티브 포팅의 기준 구현
engine/test/  단위 테스트 (node:test)
tools/        밸런스 시뮬레이션, 퍼즐 생성기, 웹 번들 빌드
web/          플레이 가능한 웹 프로토타입 (AI 대전 / 2인 대전 / 퍼즐)
```

## 실행

```bash
npm test                     # 룰 엔진 단위 테스트 (30개)
npm run simulate             # 선공 밸런스 시뮬레이션: [게임수] [깊이|t밀리초] [시드] [none|pie]
node tools/gen-puzzles.js    # 자가대전에서 퍼즐 추출 → web/puzzles.js
npm run build:web            # web/dist/index.html 단일 파일 번들 생성
npx http-server web          # 개발용 로컬 서버 (또는 web/dist/index.html을 바로 열기)
```

## 규칙 요약

- 11×11 보드, 정중앙 오아시스에 말을 먼저 도착시키면 라운드 승리. 3판 2선승.
- **슬라이드 이동**: 가장자리/다른 말에 막히기 직전까지 가로·세로로 미끄러진다.
- **L자 이동**: 나이트처럼 점프하되, 비어있는 사막 칸에만 도착 가능.
- 오아시스에는 슬라이드로만 도착할 수 있다 (반대편 인접 칸에 블로커 필요).

초기 배치는 원작 서술("각 대각선 위치에서 마주보는 형태로 5개씩")의 해석이며
`engine/src/board.js`의 상수로 정의되어 있다. 원작 영상 대조 후 확정 필요.
