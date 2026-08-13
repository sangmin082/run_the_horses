# 오너 TODO — 사람이 직접 해야 하는 일들

코드/문서로 해결할 수 없어 **프로젝트 오너의 결정·행동이 필요한 항목**.
우선순위 순서. ~~취소선~~은 결정 완료된 항목.

> 결정 완료 (2026-08-13): 보드 구성 확정 / 앱 이름 "말달리자" / iOS 네이티브 앱
> (which_combo 방식: SwiftUI + fastlane TestFlight + Render 릴레이 서버) /
> IP 리스크 없음 판단 / 무료·광고 없음·IAP 없음 모델.
> → iOS 앱 코드는 `RunHorses/`에 구현 완료.

## TestFlight 배포 준비 (which_combo와 동일 절차)

1. **App Store Connect에 앱 생성** — 번들 ID `com.runhorses.game`, 이름 "말달리자"
2. **GitHub Secrets 등록** (repo Settings → Secrets and variables → Actions) —
   which_combo에서 쓰던 값을 그대로 재사용하면 된다:
   - `APP_STORE_CONNECT_KEY_ID` / `APP_STORE_CONNECT_ISSUER_ID` / `APP_STORE_CONNECT_KEY`
   - `APPLE_TEAM_ID` / `MATCH_GIT_URL` / `MATCH_GIT_BASIC_AUTHORIZATION` / `MATCH_PASSWORD`
3. **머지 후 TestFlight 워크플로 실행** — main 푸시 시 자동, 또는 Actions 탭에서 수동
4. **Render에 서버 배포** — render.com → New → Blueprint → 이 저장소 연결
   (배포 주소가 `run-horses.onrender.com`이 아니면 `RunHorses/Online/OnlineConfig.swift` 수정)

## 현재 상태 (2026-08-14)

TestFlight 배포 파이프라인 가동 중 (빌드 4까지 업로드), 서버 배포 완료.
**남은 것은 ① 실기기 최종 테스트 ② 스크린샷 5장 ③ 심사 제출 클릭**뿐이며,
전 과정은 `docs/APP_STORE.md` §7~§9에 클릭 단위로 정리되어 있다.

## 출시 전 확인

5. **원작 7화로 보드 최종 확인** — 현재 구현(초원 12칸 다이아몬드 + 코너 ㄱ자
   배치)은 팬게임 소스와 교차 검증한 값. 방영분과 다르면 좌표만 알려줄 것.
6. **앱 아이콘 검토** — 자동 생성한 픽셀아트 아이콘이 들어 있음
   (`RunHorses/Assets.xcassets`). 교체하려면 1024×1024 PNG 하나만 바꾸면 된다.
7. **실기기 테스트** — Xcode에서 `RunHorses.xcodeproj` 열고 실행. 특히 온라인
   대전은 기기 2대(또는 기기+시뮬레이터)로 방 코드 입장 확인.
8. **스크린샷 촬영 + 심사 제출** — 목록은 `docs/APP_STORE.md` 체크리스트 참고.
9. **베타 테스터 모집** — TestFlight 외부 테스터 (원작 팬 커뮤니티가 최적).
10. **PR/머지 결정** — 현재 모든 작업이 `claude/horse-racing-game-plan-o5vcpd`
    브랜치에 있음. PR을 만들어 리뷰/머지할지 알려주면 처리함 (TestFlight는 main
    머지 후 동작).

## 참고

- 웹 프로토타입 (게임 미리 체험):
  https://claude.ai/code/artifact/2d03a38a-3a1c-4ecb-8829-70a5902d7679
- 앱스토어 제출 자료 초안: `docs/APP_STORE.md`
