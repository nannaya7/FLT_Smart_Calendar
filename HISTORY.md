# 개발 히스토리

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
