# App Store 업로드 절차

> Bundle ID: `com.leescasa.calendar`
> 대상 플랫폼: iOS (App Store Connect)

---

## 0. 사전 준비

| 항목 | 확인 |
|---|---|
| Apple Developer Program 등록 (연 $99) | ☐ |
| App Store Connect에 앱 등록 완료 | ☐ |
| 배포용 인증서 (Distribution Certificate) 발급 | ☐ |
| App Store 프로비저닝 프로파일 생성 | ☐ |
| Xcode 최신 버전 설치 | ☐ |

---

## 1. 버전 번호 업데이트
`smart_calendar/pubspec.yaml`의 `version` 필드를 수정한다.

```yaml
# 형식: 마케팅버전+빌드번호
version: 1.0.1+2
#        ↑       ↑
#  CFBundleShortVersionString (앱스토어 표시 버전)
#                CFBundleVersion (빌드 번호, 매 업로드마다 증가)
```

> **규칙**: 빌드 번호는 이전 업로드보다 반드시 높아야 한다. 같은 버전을 재업로드할 때도 빌드 번호를 올린다.

---

## 2. Release 빌드 생성

터미널에서 프로젝트 루트(`smart_calendar/`)로 이동 후 실행:

```bash
cd smart_calendar

flutter build ipa \
  --release \
  --dart-define=HOLIDAY_API_KEY=bb8460ec9fd251fdcaa97a8943b21e1b58d24ccb4f724b29966e2d0d57f6fc4a \
  --export-method app-store
```

> `HOLIDAY_API_KEY`가 없으면 특일 연동 없이 빌드된다. 공공데이터포털 키가 있을 때만 `--dart-define`을 추가한다.

빌드 성공 시 아카이브 파일이 생성된다:

```
build/ios/archive/Runner.xcarchive
```

---

## 3. Xcode에서 빌드 설정 확인 (선택)

빌드 전 Xcode에서 직접 확인하고 싶을 때:

1. `smart_calendar/ios/Runner.xcworkspace` 파일을 Xcode로 열기
2. `Runner` 타겟 선택 → **Signing & Capabilities** 탭
   - Team: 올바른 Apple 계정 선택
   - Bundle Identifier: `com.leescasa.calendar`
   - Signing Certificate: **Apple Distribution**
   - Provisioning Profile: **App Store 프로파일** 선택
3. **General** 탭에서 Version / Build 번호 확인

---

## 4. Xcode Organizer로 업로드

### 방법 A — Xcode GUI

1. **Product → Archive** 실행 (또는 flutter build ipa 후 생성된 xcarchive 사용)
2. **Window → Organizer** 열기 (`Shift+Cmd+O`)
3. 생성된 아카이브 선택 → **Distribute App** 클릭
4. 배포 방법 선택: **App Store Connect**
5. **Upload** 선택 → Next
6. 옵션 확인 (기본값 유지):
   - Strip Swift symbols: ✅
   - Upload symbols: ✅
7. 인증서/프로파일 자동 선택 또는 수동 지정 후 **Upload** 클릭
8. 업로드 완료 메시지 확인

### 방법 B — xcrun altool (CLI, 레거시)

```bash
xcrun altool --upload-app \
  -f build/ios/ipa/*.ipa \
  -t ios \
  -u <Apple_ID_이메일> \
  -p <앱_전용_비밀번호>
```

> 앱 전용 비밀번호: [appleid.apple.com](https://appleid.apple.com) → 보안 → 앱 전용 암호

### 방법 C — xcrun notarytool / Transporter 앱

Transporter 앱(Mac App Store 무료)으로 .ipa 파일을 드래그 앤 드롭 후 Deliver 클릭.

---

## 5. App Store Connect에서 심사 제출

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) 접속
2. **나의 앱** → Smart Calendar 선택
3. **+ 버전 또는 플랫폼** → iOS 버전 번호 입력
4. 업로드된 빌드가 처리될 때까지 대기 (보통 5~30분, 메일 알림 옴)
5. 처리 완료 후 해당 빌드 선택
6. 필수 입력 항목 작성:
   - **업데이트 새로운 기능** (What's New): 이번 버전 변경 사항
   - 스크린샷 (기기별 최신 상태 확인)
   - 개인정보 처리방침 URL (필요 시)
7. **심사를 위해 제출** 클릭

---

## 6. 심사 진행 상황 확인

- App Store Connect 대시보드에서 상태 추적
- 일반적으로 24~48시간 내 결과 통보
- 거절 시 Resolution Center에서 사유 확인 후 수정 재제출

---

## 7. 업로드 전 체크리스트

```
[ ] pubspec.yaml 버전/빌드 번호 업데이트
[ ] HOLIDAY_API_KEY 유무 확인 (없어도 앱 동작 확인)
[ ] flutter analyze — 경고 없음 확인
[ ] iOS 실기기 테스트 완료 (최소 iPhone SE, Pro Max)
[ ] 앱 아이콘 / 스플래시 최신 상태
[ ] Info.plist 권한 문구 (알림, 위치 등) 최신 상태
[ ] App Store Connect 스크린샷 최신 상태
[ ] What's New 문구 작성 완료
```

---

## 8. 자주 쓰는 명령어

```bash
# 버전 확인
grep version smart_calendar/pubspec.yaml

# 클린 빌드
cd smart_calendar && flutter clean && flutter pub get

# Release IPA 빌드
flutter build ipa --release --dart-define=HOLIDAY_API_KEY=<KEY>

# 분석
flutter analyze

# 아카이브 경로 열기
open build/ios/archive/
```

---

## 9. 주의사항

- `doc/openapi.txt`는 API 인증키가 포함되어 있으므로 **절대 커밋하지 않는다**
- `HOLIDAY_API_KEY`는 소스코드에 하드코딩하지 않는다
- 빌드 번호(+N)는 한 번 올리면 내릴 수 없다 (같은 번호 재사용 불가)
- TestFlight 내부 테스트 후 심사 제출하는 것을 권장한다
