# 말달리자 출시 가이드 — 처음부터 끝까지

현재 상태: 앱 코드·서버·배포 파이프라인은 전부 완성되어
`claude/horse-racing-game-plan-o5vcpd` 브랜치에 있고 CI(컴파일·테스트)까지 통과했다.
남은 것은 **계정 연결과 버튼 누르기**뿐이며, 아래 순서대로 하면 된다.
(which_combo를 출시해 봤다면 같은 절차의 반복이다)

---

## STEP 1. Apple/GitHub 준비물 새로 만들기 (20분)

> which_combo 것을 재사용하지 않고 전부 새로 만드는 절차. (Team ID만 계정
> 고유값이라 동일하다)

**1-1. App Store Connect API 키 새로 생성** — [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
→ 사용자 및 액세스 → **통합(Integrations)** → App Store Connect API → **API 키 생성(+)**

- 이름: `run-horses-ci` / 액세스 권한: **App Manager**
- 생성 직후 화면에서 ① **Issuer ID**(상단, 팀 공통 UUID) ② 방금 만든 키의
  **Key ID** 메모, ③ **API 키 다운로드** 클릭 → `AuthKey_XXXXXXXX.p8` 저장
- ⚠️ p8 다운로드 버튼은 **한 번만** 나타난다. 지금 바로 안전한 곳에 보관할 것.

**1-2. Team ID 확인** — [developer.apple.com/account](https://developer.apple.com/account)
→ Membership details → **Team ID** (10자리) 메모.

**1-3. 인증서 저장소(match repo) 새로 생성** — GitHub에서
**New repository** → 이름 `run-horses-certificates` → **Private** ✅ → Create.
(README 등 아무것도 추가하지 않은 빈 저장소면 된다. fastlane match가 여기에
배포 인증서와 프로비저닝 프로파일을 암호화해 저장한다)

**1-4. MATCH_PASSWORD 정하기** — 인증서 암호화에 쓸 비밀번호를 새로 정한다
(아무 문자열이나 가능, 예: 비밀번호 관리자로 생성). 어딘가에 보관해 둘 것 —
나중에 다른 기계에서 인증서를 복호화할 때 필요하다.

**1-5. GitHub PAT(토큰) 새로 생성** — GitHub → Settings → Developer settings →
Personal access tokens → **Fine-grained tokens** → Generate new token

- Repository access: **Only select repositories** → `run-horses-certificates` 선택
- Permissions → Repository permissions → **Contents: Read and write**
- 만료 기간은 편한 대로 (만료되면 Secrets만 갱신하면 된다)
- 생성된 `github_pat_...` 문자열 메모

> 참고: Apple 배포 인증서(iOS Distribution)는 팀당 최대 2~3개다. which_combo의
> match가 이미 인증서를 만들었으므로, 새 저장소로 match를 돌리면 인증서를 하나 더
> 만들려고 시도한다. 한도 초과 오류("maximum number of certificates")가 나면
> Claude에게 알릴 것 — which_combo 인증서 재사용 또는 기존 인증서 정리로 해결한다.

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
| `APP_STORE_CONNECT_KEY` | p8 파일을 텍스트 편집기로 열어 내용 전체 붙여넣기 (`-----BEGIN PRIVATE KEY-----`부터 끝까지) |
| `APPLE_TEAM_ID` | STEP 1-2의 Team ID |
| `MATCH_GIT_URL` | `https://github.com/<계정>/run-horses-certificates` |
| `MATCH_GIT_BASIC_AUTHORIZATION` | STEP 1-5의 PAT (`github_pat_...` 단독으로 넣으면 됨) |
| `MATCH_PASSWORD` | STEP 1-4에서 정한 비밀번호 |

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
