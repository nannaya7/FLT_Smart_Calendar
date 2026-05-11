# 개발 히스토리

## V.0.00.520 — 2026-05-11

### 문서 현행화
- 공휴일·24절기 데이터 소스를 공공데이터포털 한국천문연구원 특일 정보 API 기준으로 진행하기로 정리
- 공공데이터포털 API 키가 아직 미발급 상태임을 README/협업 문서에 명시
- API 키 없이 실행할 때 공휴일·절기 연동은 건너뛰고 음력 데이터와 로컬 일정 기능으로 동작하는 방향을 문서화
- README의 일정 관리 설명을 현재 구현 상태에 맞게 추가/수정/삭제로 갱신
- 향후 계획에 공공데이터포털 일원화, API 키 발급 후 검증, 이전 Google Calendar 공휴일 연동 코드 정리를 추가
- `doc/current_design.md` 현행 설계서 추가

### 메인 달력 UI 개편
- 기존 웜 브라운 배경 + 반투명 카드형 레이아웃에서 월별 이미지 히어로 + 흰색 카드형 달력/일정 패널 구조로 변경
- 상단 헤더를 큰 월 숫자, 연도, 영문 월명 조합으로 재구성
- 월 헤더 폰트를 `Pretendard`로 통일
- 월별 배경 이미지의 흰색 오버레이 투명도를 높여 이미지가 더 잘 보이도록 조정
- 달력 카드 그림자, 모서리, 여백을 요청 이미지 기준으로 조정
- 일정 패널을 흰색 리스트 카드 스타일로 변경하고 하단 응원 문구 추가

### 날짜 셀 레이아웃 조정
- 요일 헤더를 `SUN MON TUE WED THU FRI SAT` 영문 표기로 변경
- 날짜 셀의 행 높이, 날짜 영역 높이, 양력/음력 사이 간격을 여러 차례 미세 조정
- 음력 표시에서 `음` 접두어 제거
- 음력 폰트 크기를 키우고, 양력/음력 폰트 조절 위치에 한글 주석 추가
- 선택 날짜 배경을 연한 블루 계열 라운드 사각형으로 조정
- Dot 마커 크기와 양력/음력 간격을 조정해 작은 iPhone과 Pro Max 모두에서 균형을 맞춤

### 기기별 표시 안정화
- `MaterialApp.builder`에서 `TextScaler.noScaling`을 적용해 iOS 텍스트 크기 설정 차이에 따른 폰트 크기 변동을 억제
- iPhone과 iPhone Pro Max 간 표시 차이를 비교하며 날짜 셀 폰트 굵기, 줄림 여부, 간격을 점검

### 월 전환 애니메이션
- 기존 blur/fade 방식의 월 전환 효과를 좌우 슬라이드 방식으로 변경
- 다음 달은 오른쪽에서 들어오고, 이전 달은 왼쪽에서 들어오는 방향성 추가
- `연도-월` 기반 key를 사용해 연도 변경 시에도 전환이 안정적으로 동작하도록 수정

### 테스트 정리
- 기본 Flutter 카운터 템플릿 테스트가 `MyApp`을 참조하던 문제 수정
- 현행 앱 클래스인 `SmartCalendarApp` 기준의 간단한 smoke test로 교체
- 주요 변경 후 `flutter analyze`, `flutter test` 통과 확인

---

## V.0.00.510 — 2026-05-07

### 문서 정리
- `HISTORY.md` 생성 (개발 히스토리 문서화)
- `README.md` 현행 기능 기준으로 전면 갱신 (DB 스키마 v4, 반복·음력 기능 반영)
- `Korean_holiday.md` → `doc/Korean_holiday.md` 이동
- `smart_calendar_v1.md` → `doc/smart_calendar_v1.md` 이동

---

## V.0.00.500 — 2026-05-07

### 반복 일정 + 음력 일정 등록 + 인라인 패널 전환

#### DB 스키마 v4
- `schedules` 테이블에 컬럼 3개 추가
  - `repeat_type TEXT` — `null` | `'daily'` | `'monthly'` | `'yearly'`
  - `lunar_month INTEGER` — 음력 월 (is_lunar=1 일 때)
  - `lunar_day INTEGER` — 음력 일 (is_lunar=1 일 때)
- `_dbVersion` 2 → 4 (`_onUpgrade` v3·v4 마이그레이션 각각 적용)
- `getLunarYearlySchedules()` 메서드 추가 — 음력 매년 반복 일정 전체 조회

#### 음력 변환 API (`CalendarEngine`)
- `solarToLunar(DateTime)` 추가 — 양력 → 음력 변환
- `lunarToSolar(year, month, day)` 추가 — 음력 → 양력 환산 (범위 초과 시 null)

#### 일정 등록 (`ScheduleFormSheet`)
- 양력 / 음력 모드 토글 (`_isLunar` 상태)
- 음력 선택 시 `lunarMonth` · `lunarDay` 필드에 변환값 저장
- 반복 칩 UI 추가: 없음 / 매일 / 매월 / 매년
- 알림 반복 처리: `DateTimeComponents.time`(매일), `dayOfMonthAndTime`(매월), 단발(매년 — 플러그인 미지원)

#### 달력 UI (`CalendarPage`)
- BottomSheet 방식 → 하단 고정 인라인 패널(`height: 190`)으로 전환
- 패널 헤더: 양력·음력 날짜 동시 표기 + 해당일 절기·명절 서브텍스트
- 일정 아이템에 음력 배지(amber) 및 반복 아이콘(purple) 표시
- 음력 매년 반복 일정: `getLunarYearlySchedules()`로 매년 양력 환산일에 자동 표시
- Dot 마커 집계 개선: 음력 매년 반복 일정 중복 카운트 제거

#### 버그 수정
- 음력 매년 반복 일정이 패널에 2개 중복 표시되던 문제 수정
  - 원인: `getSchedulesByDate()`와 `getLunarYearlySchedules()` 두 경로가 동일 레코드 반환
  - 수정: 정규 조회 ID 셋(`regularIds`)으로 음력 결과 중복 필터링

#### Android 빌드 설정
- `build.gradle.kts`에 `isCoreLibraryDesugaringEnabled = true` 및 `desugar_jdk_libs:2.1.4` 추가
  (Java 8+ API 하위 호환 — `timezone` 패키지 요구사항)

---

## V.0.00.220 — 2026-05-07

### UI 개선
- 전체 배경 그라디언트를 웜 브라운 계열로 변경 (`#97867B → #807169`)
- 계절 텍스트 필 제거 → 달력 보드를 상단으로 올려 공간 확보
- 날짜 선택 데코레이션: 원형 → 라운드 사각형 회색 테두리 (`BorderRadius.circular(10)`, `Colors.grey`)

### 인라인 일정 패널 (모달 → 인라인 전환)
- 날짜 탭 시 BottomSheet 팝업 대신 하단 고정 패널(`height: 190`)에 일정 표시
- `day_schedule_sheet.dart` 역할을 `calendar_page.dart` 내 `_buildInfoPanel()` / `_panelContent()`로 통합
- 패널 헤더에 양력·음력 날짜 동시 표기, 해당일 음력 절기·명절 서브텍스트 표시
- 일정 아이템에 음력 배지(amber) 및 반복 아이콘(purple) 추가

### 일정 반복 기능
- 반복 유형 3종 추가: 매일(`daily`) / 매월(`monthly`) / 매년(`yearly`)
- `ScheduleFormSheet`에 반복 칩 UI 추가
- 알림 반복: `DateTimeComponents.time` (매일), `dayOfMonthAndTime` (매월), 단발(매년 — 플러그인 한계)

### 음력 일정 등록
- 일정 등록 시 양력/음력 모드 토글 (`_isLunar` 상태)
- 음력 선택 시 변환된 음력 월·일 저장 (`lunarMonth`, `lunarDay` 필드)
- 음력 매년 반복 일정: 매년 해당 음력 날짜의 양력 환산일에 자동 표시

### DB 스키마 v4
- `repeat_type TEXT` 컬럼 추가 (`null` | `'daily'` | `'monthly'` | `'yearly'`)
- `lunar_month INTEGER`, `lunar_day INTEGER` 컬럼 추가
- `getLunarYearlySchedules()` 쿼리 메서드 추가

### 버그 수정
- 음력 매년 반복 일정이 패널에 2개 중복 표시되던 문제 수정
  - 원인: `getSchedulesByDate()`와 `getLunarYearlySchedules()` 두 경로가 동일 레코드 반환
  - 수정: 정규 조회 ID 셋(`regularIds`)으로 음력 결과 필터링, 점 마커 집계에서 `isLunar && yearly` 스킵

---

## V.0.00.210 — 2026-05-06

### UI 개선
- 날짜 숫자 폰트 크기 1.5배 확대 (`15 → 22.5`)
- 음력 서브텍스트 폰트 크기 1.5배 확대 (`8 → 12`)

---

## V.0.00.200 — 2026-05-06

### Step 4: 일정 등록 UI + 푸시 알림 완성

#### 추가 파일
- `lib/core/notifications/notification_service.dart`
  - 싱글톤. `init()`, `requestAndroidPermission()`, `schedule()`, `cancel()`
  - `timezone` 패키지 연동, `Asia/Seoul` 로케일 설정
  - `zonedSchedule` + `AndroidScheduleMode.exactAllowWhileIdle`
- `lib/features/schedule/schedule_form_sheet.dart`
  - 일정 등록 BottomSheet (제목·메모·시간·알림 프리셋·카테고리 색상)
  - 알림 칩: 정시 / 10분 전 / 30분 전 / 1시간 전 / 하루 전 (시간 미설정 시 숨김)
- `lib/features/schedule/day_schedule_sheet.dart`
  - 날짜별 일정 목록 BottomSheet (최대 화면 75%)
  - 스와이프(→←) 삭제 + 알림 취소
  - 빈 목록 안내 메시지

#### 수정 파일
- `lib/features/calendar/calendar_page.dart`
  - `_onDayTap` 메서드 추출 (context-after-async 경고 해결)
  - `DayScheduleSheet` 연동 — 닫힌 후 Dot 마커 재로드
  - `initState`에서 Android 알림 권한 요청
- `lib/main.dart`
  - `NotificationService.instance.init()` 앱 시작 시 초기화
- `android/app/src/main/AndroidManifest.xml`
  - 권한: `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `SCHEDULE_EXACT_ALARM`, `POST_NOTIFICATIONS`
  - Receiver: `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`
- `ios/Runner/AppDelegate.swift`
  - `UNUserNotificationCenter.current().delegate = self` 추가

#### pubspec.yaml
- `flutter_local_notifications: ^18.0.0` 추가
- `timezone: ^0.9.4` 추가

---

## V.0.00.100 — 2026-05-06

### Step 3: 공공데이터포털 API 연동 + DB 캐싱

#### 추가 파일
- `lib/shared/models/holiday.dart`
  - `Holiday` 모델 (id, date, name, type)
  - `type`: `'holiday'` (법정 공휴일) | `'solar_term'` (24절기)
- `lib/core/api/holiday_api_service.dart`
  - `fetchHolidays(year)` → `getHoliDeInfo` API (isHoliday == 'Y' 필터)
  - `fetchSolarTerms(year)` → `get24DivisionsInfo` API
  - API 응답 단건/복수 처리: `items is List ? items : [items]`
  - API 키 없을 시 빈 리스트 반환 (graceful degradation)

#### 수정 파일
- `lib/core/db/database_helper.dart`
  - DB 버전 1 → 2
  - `holidays` 테이블 추가 (`onUpgrade` + `onCreate` 모두 처리)
  - `insertHolidays()`, `getHolidaysByYear()`, `hasHolidaysForYear()` 추가
- `lib/features/calendar/calendar_page.dart`
  - `_holidays` 맵, `_loadedHolidayYears` 셋 추가
  - `_loadHolidays(year)` — DB 캐시 우선, 없으면 API 호출
  - 날짜 셀 색상: `isPublicHoliday`(API 기준)만 빨강 적용
  - 서브텍스트 우선순위: API 데이터 > 음력 명절 > 음력 날짜

#### pubspec.yaml
- `http: ^1.2.0` 추가

#### 버그 수정
- 음력 전통 명절(단오·칠석 등) 날짜 숫자가 빨간색으로 잘못 표시되던 문제 수정
  - 원인: `CalendarEngine.cellInfo().holiday != null` 조건이 색상 로직에 포함
  - 수정: 날짜 색상은 `isPublicHoliday`(법정 공휴일) + `isSun`만 빨강

---

## V.0.00.010 — 2026-05-06

### Step 2: 달력 UI + 음력 표시

#### 추가 파일
- `lib/core/calendar_engine.dart`
  - `CalendarEngine` 싱글톤 — `korean_lunar_utils` 래핑
  - `cellInfo(DateTime)` → `lunarLabel`, `isSpecial`, `holiday`
- `lib/features/calendar/calendar_page.dart`
  - `TableCalendar` 커스텀 빌더 — 요일 헤더, 날짜 셀
  - 날짜 셀: 양력 숫자 + 음력 서브텍스트 + Dot 마커 (Column 구조)
  - 그라디언트 배경 (`#3A7272 → #CC7840`), 헤더 네비게이션

#### pubspec.yaml
- `table_calendar: ^3.1.2` 추가
- `korean_lunar_utils: ^1.0.1` 추가 (`korean_lunar_calendar` 대체)

---

## V.0.00.001 — 2026-05-06

### Step 1: 데이터 모델 + sqflite DB 헬퍼

#### 추가 파일
- `lib/shared/models/schedule.dart` — `Schedule` 모델
- `lib/core/db/database_helper.dart`
  - DB 버전 1, `schedules` 테이블 생성
  - `insertSchedule()`, `getSchedulesByDate()`, `getSchedulesByMonth()`, `deleteSchedule()`
- `lib/main.dart` — Flutter 앱 엔트리포인트

#### pubspec.yaml
- `sqflite: ^2.4.2`, `path: ^1.9.1` 추가
