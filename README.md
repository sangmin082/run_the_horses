# 말달리자 (Run the Horses)

데스게임 7회차 <말 달리자>를 iOS 게임으로 구현한 프로젝트입니다.
([which_combo](https://github.com/sangmin082/which_combo)와 같은 구조 — SwiftUI 앱 + Node.js 릴레이 서버)

- **혼자 하기** — AI와 오아시스 경주 (난이도 4단계, 전문가는 깊이 9 수읽기)
- **둘이 하기** — 방 코드 하나로 친구와 실시간 온라인 대전
- **튜토리얼 / 퍼즐** — 3단계 행마법 학습 + "N수 안에 도착" 12문제
- 매치 형식: **단판 승부** (선공 무작위 — 원작의 3판 2선승은 엔진 상수로 되돌릴 수 있음)

개발 문서: [PLAN.md](PLAN.md) · [규칙 명세](docs/rules-spec.md) ·
[밸런스 실험](docs/balance-report.md) · [팬게임 비교](docs/competitor-analysis.md) ·
[앱스토어 제출 자료](docs/APP_STORE.md) · [오너 TODO](docs/owner-todo.md)

## 구성

```
RunHorses.xcodeproj          Xcode 16+ 프로젝트 (iOS 17+)
RunHorses/
├── App/RunHorsesApp.swift
├── Game/
│   ├── GameEngine.swift     규칙 상태기계 (순수 값 타입 — 양쪽 기기에서 동일 재현)
│   ├── AIPlayer.swift       네가맥스+알파베타+TT+반복심화 AI (4단계 난이도)
│   ├── GameViewModel.swift  대국 진행, AI 스케줄, 튜토리얼/퍼즐 판정, 무르기
│   ├── Puzzles.swift        퍼즐 데이터 (tools/gen-puzzles.js가 자동 생성)
│   ├── StatsStore.swift     전적·퍼즐 기록 저장
│   └── EngineSelfTest.swift JS 레퍼런스와 동일 시나리오의 규칙 검증 (DEBUG)
├── Online/RoomClient.swift  WebSocket 클라이언트 (방 생성/코드 입장/무브 릴레이)
└── Views/                   홈, 대국(11×11 보드), 튜토리얼·퍼즐, 온라인 로비, 규칙, 전적
server/                      2인용 릴레이 서버 (Node.js + ws, Render 배포)
engine/                      JS 레퍼런스 룰 엔진 + 단위 테스트 30개 (포팅 검증 기준)
tools/                       밸런스 시뮬레이션, 퍼즐 생성기, 웹 번들 빌드, 아이콘 생성
web/                         웹 프로토타입 (AI 대전 / 2인 대전 / 튜토리얼 / 퍼즐)
```

## iOS 앱 실행 (Xcode 16 이상, iOS 17+)

```bash
open RunHorses.xcodeproj
```

TestFlight 배포는 GitHub Actions `TestFlight` 워크플로가 담당한다
(필요한 Secrets는 `fastlane/Fastfile` 상단 주석 참고).
온라인 대전 서버는 `render.yaml`로 Render에 배포한다.

## 실행

```bash
npm test                     # 룰 엔진 단위 테스트 (30개)
npm run simulate             # 선공 밸런스 시뮬레이션: [게임수] [깊이|t밀리초] [시드] [none|pie]
node tools/gen-puzzles.js    # 자가대전에서 퍼즐 추출 → web/puzzles.js
npm run build:web            # web/dist/index.html 단일 파일 번들 생성
npx http-server web          # 개발용 로컬 서버 (또는 web/dist/index.html을 바로 열기)
```

## 규칙 요약

- 11×11 보드, 정중앙 오아시스에 말을 먼저 도착시키면 승리 (앱은 단판, 원작은 3판 2선승).
- **슬라이드 이동**: 가장자리/다른 말에 막히기 직전까지 가로·세로로 미끄러진다.
- **L자 이동**: 나이트처럼 점프하되, 비어있는 사막 칸에만 도착 가능.
- 오아시스에는 슬라이드로만 도착할 수 있다 (반대편 인접 칸에 블로커 필요).

보드 구성(초원 = 중앙 맨해튼 거리 2 이내 12칸, 초기 배치 = 대각 방향 두 코너의
ㄱ자 브래킷 5개씩)은 팬게임 horse-run-game 소스와 교차 검증했다
([비교 분석](docs/competitor-analysis.md)). 최종 확정은 원작 영상 대조로 한다.
