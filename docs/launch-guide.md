# 말달리자 출시 가이드 — 처음부터 끝까지

현재 상태: 앱 코드·서버·배포 파이프라인은 전부 완성되어
`claude/horse-racing-game-plan-o5vcpd` 브랜치에 있고 CI(컴파일·테스트)까지 통과했다.
남은 것은 **계정 연결과 버튼 누르기**뿐이며, 아래 순서대로 하면 된다.
(which_combo를 출시해 봤다면 같은 절차의 반복이다)

---

## STEP 1. Apple 준비물 확인 (10분)

**1-1. App Store Connect API 키** — [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
→ 사용자 및 액세스 → **통합(Integrations)** → App Store Connect API

- which_combo 때 만든 키가 목록에 있으면 그대로 재사용: **Key ID**와 **Issuer ID**를 메모.
- ⚠️ p8 비밀키 파일은 생성 때 한 번만 다운로드된다. 로컬에 보관해둔 `AuthKey_XXXX.p8`
  파일을 찾을 것. 못 찾겠으면 "키 생성"으로 새로 만들면 된다 (권한: App Manager).

**1-2. Team ID** — [developer.apple.com/account](https://developer.apple.com/account)
→ Membership details → **Team ID** (10자리) 메모.

**1-3. match 인증서 저장소** — which_combo의 fastlane match가 쓰던
**private 저장소 URL**(예: `https://github.com/sangmin082/certificates`)과
**MATCH_PASSWORD**(인증서 암호화 비밀번호)를 그대로 재사용한다.

## STEP 2. 번들 ID 등록 (3분)

[developer.apple.com/account/resources/identifiers](https://developer.apple.com/account/resources/identifiers)
→ **+** → App IDs → App 선택 →

- Description: `MalDallija`
- Bundle ID: **Explicit** → `com.runhorses.game`
- Capabilities: 기본값 그대로 → Register

## STEP 3. App Store Connect에 앱 생성 (3분)

[appstoreconnect.apple.com](https://appstoreconnect.apple.com) → 나의 앱 → **+ → 신규 앱**

- 플랫폼: iOS / 이름: **말달리자** / 기본 언어: 한국어
- 번들 ID: `com.runhorses.game` 선택 / SKU: `run-horses`

## STEP 4. GitHub Secrets 등록 (5분)

`run_the_horses` 저장소 → Settings → Secrets and variables → **Actions** →
New repository secret으로 7개 등록:

| 이름 | 값 |
|---|---|
| `APP_STORE_CONNECT_KEY_ID` | STEP 1-1의 Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | STEP 1-1의 Issuer ID |
| `APP_STORE_CONNECT_KEY` | p8 파일 내용 전체 (원문/base64 모두 허용) |
| `APPLE_TEAM_ID` | STEP 1-2의 Team ID |
| `MATCH_GIT_URL` | 인증서 저장소 https URL |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `깃허브계정:PAT` (PAT 단독도 허용) |
| `MATCH_PASSWORD` | which_combo와 동일한 match 비밀번호 |

> PAT은 인증서 저장소에 read/write 권한이 있어야 한다 (which_combo 때 쓰던 것 재사용).

## STEP 5. PR 머지

Claude에게 **"PR 만들어줘"** → 생성된 PR에서 내용 확인 후 **Merge**.

머지 즉시 두 가지가 자동 실행된다:
- **CI** — 컴파일·테스트 재검증
- **TestFlight 워크플로** — 빌드 후 TestFlight 업로드 (Actions 탭에서 진행 확인, 15분 내외)

실패하면 Actions 로그를 Claude에게 보여주거나 "TestFlight 실패했어"라고 하면 된다.

## STEP 6. 온라인 대전 서버 배포 (5분, 머지 후)

[render.com](https://render.com) → New **+** → **Blueprint** → GitHub 계정 연결 →
`run_the_horses` 저장소 선택 → Apply

- 배포가 끝나면 `https://run-horses.onrender.com/privacy` 가 열리는지 확인
  (이 주소가 앱스토어 심사에 넣을 개인정보 처리방침 URL이다)
- 서비스 이름이 달라져서 주소가 다르면 Claude에게 알려줄 것
  (`RunHorses/Online/OnlineConfig.swift` 한 줄 수정 필요)

## STEP 7. TestFlight 설치 & 테스트 (30분)

1. App Store Connect → 말달리자 → **TestFlight** 탭 — 빌드 처리 완료 대기 (10~30분)
2. 내부 테스팅 그룹 만들고 본인 Apple ID 추가
3. 아이폰의 TestFlight 앱에서 말달리자 설치
4. 확인할 것:
   - 혼자 하기 (난이도 4개 다), 튜토리얼 3단계, 퍼즐 몇 개
   - 무르기, 전적 기록
   - **둘이 하기**: 기기 2대(또는 친구)로 방 코드 생성 → 입장 → 대국
   - 버그를 찾으면 Claude에게 증상 전달

## STEP 8. 심사 제출 (1시간)

1. **스크린샷 촬영** — 6.9" (iPhone 16 Pro Max급) 필수. 실기기나 Xcode 시뮬레이터에서:
   홈 / 대국(이동 힌트 보이게) / 승리 장면 / 튜토리얼 / 퍼즐 목록
2. App Store Connect → 말달리자 → 앱 정보·가격(무료)·개인정보 입력
   - 부제/프로모션 텍스트/설명/키워드/심사 메모: **`docs/APP_STORE.md`에서 복사**
   - 개인정보 처리방침 URL: `https://run-horses.onrender.com/privacy`
   - 데이터 수집: **"데이터를 수집하지 않음"** 선택
3. 연령 등급 설문: 전부 "없음" → 4+
4. 빌드 선택 (STEP 7의 TestFlight 빌드) → **심사 제출**
5. 심사는 보통 1~2일. 리젝되면 사유를 Claude에게 전달

## STEP 9. 출시 후 (선택)

- 원작 7화 다시보기로 초기 배치·초원 모양 최종 대조 (다르면 좌표 전달 → 즉시 패치)
- 팬 커뮤니티에 출시 소식 공유, TestFlight 외부 테스터 모집
- 업데이트 아이디어: 파이 룰 옵션 UI, 랭크/전적 확장, 밸런스 실험 계속

---

### 문제 해결 빠른 참조

| 증상 | 조치 |
|---|---|
| TestFlight 워크플로 실패 | Actions 로그 → Claude에게. 대부분 Secrets 값 문제 |
| 온라인 연결 안 됨 | Render 서비스가 잠자기 상태면 첫 연결에 최대 1분. `/privacy` 열리는지 확인 |
| 서버 주소가 다름 | Claude에게 새 주소 전달 → OnlineConfig 수정 커밋 |
| 심사 리젝 | 리젝 사유 전문을 Claude에게 |
