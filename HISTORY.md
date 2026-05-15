# 개발 히스토리

## V.0.30.101 — 2026-05-15

### 앱 아이콘 교체
- `pubspec.yaml` `flutter_launcher_icons.image_path`를 `calendar_icon2.png`로 변경

### 스플래시 화면 교체
- `splash_screen1.png`를 Android `drawable-nodpi/splash_screen.png` 및 iOS `LaunchImage.imageset/` (LaunchImage, @2x, @3x) 모두에 적용

### 앱 정보 화면 개선
- `app_info1.png` 이미지로 교체
- `_AppActionRow`에 `showArrow` 파라미터 추가 — 화살표를 오픈소스 라이선스 행에서만 표시
- 평가하기 행 및 해당 구분선 삭제

### 월간 일정 팝업 (`_MonthlyScheduleSheet`) 전면 개선

#### 높이 및 탭 구조
- 팝업 높이 20% 증가: `size.height * 0.75` → `size.height * 0.90`
- 4개 탭으로 분리: 나의 일정 / 공휴일 / 기념일 / 전체
  - `SingleTickerProviderStateMixin` + `TabController(length: 4)` 적용
  - `TabBar` + `TabBarView(physics: NeverScrollableScrollPhysics())`

#### 데이터 분리
- 단일 `_items` → `_mySchedules`, `_publicHolidays`, `_anniversaries`, `_allItems` 4개 리스트
  - 공휴일 탭: `rest_day`, `national_holiday` 타입
  - 기념일 탭: `solar_term`, `anniversary` 타입
  - 전체 탭: 3개 목록 합산 후 날짜순 정렬

#### 사잇날 감지
- 주중 평일 중 전날·다음날이 모두 쉬는 날(주말 또는 공휴일)이면 사잇날으로 판별
- 공휴일·전체 탭에만 초록색(`0xFF4FA96A`)으로 표시 (달력에는 미표시)
- `_isNonWorking(DateTime)` 헬퍼 메서드 추가
- `_MonthItem`에 선택적 `titleColor` 필드 추가

#### 탭 스와이프 네비게이션
- `GestureDetector.onHorizontalDragEnd` (임계값 primaryVelocity 300)
- 우→좌 스와이프: 다음 탭 이동; 마지막 탭(전체)에서 → 다음 달 나의 일정 탭
- 좌→우 스와이프: 이전 탭 이동; 첫 탭(나의 일정)에서 → 이전 달 전체 탭
- `_changeMonth(int delta, {int targetTab})` 메서드 — 달 전환 + 탭 초기화 연동
- `_buildHeader`가 `_month` 상태 기준으로 렌더링 (달 전환 후에도 헤더 갱신)

---

## V.0.20.x — 2026-05-14

### UI 전면 재설계

#### CalendarPage 구조 분리
- 기존 `calendar_page.dart` 내 인라인 위젯을 독립 클래스로 분리
  - `_CalendarLayout` — 화면 너비(compact < 370 / normal / expanded ≥ 430) 기준으로 폰트·패딩·높이를 `lerp()`로 선형 보간하는 반응형 레이아웃 클래스
  - `_CalendarDayCell` — 날짜 셀 StatelessWidget (양력 숫자 / dot 마커 / 음력·특일 서브텍스트)
  - `_DowCell` — 요일 헤더 셀 (MON ~ SUN)
  - `_ScheduleListItem` — Slidable 기반 일정 목록 아이템 (수정·삭제 슬라이드 액션 + 음력 배지 + 반복 아이콘 + 알람 아이콘)
  - `_BarTapArea` — 하단 액션바 버튼 터치 영역 (Semantics 포함)
  - `_BackgroundPickerSheet` / `_BackgroundActionTile` — 배경 이미지 선택 시트

#### 스와이프 액션바 (`_buildSwipeActionBar`)
- 화면 전체 `GestureDetector`의 수직 스와이프(28pt 이상)로 액션바 노출/숨김
- `AnimatedSlide` + `AnimatedOpacity` 조합으로 하단에서 올라오는 애니메이션
- `bar/BAR.png` 이미지 위에 투명 터치 영역 3개 배치: 앨범 / 일정 / 정보
- 현재 정보 버튼은 SnackBar 메시지로 placeholder 처리

#### 월별 배경 이미지 커스터마이징
- 앨범 버튼 탭 → `_BackgroundPickerSheet` 표시
- `ImagePicker`로 사진 선택 → `getApplicationDocumentsDirectory()/month_backgrounds/` 복사 저장
- `SharedPreferences`에 월별 경로 저장 (`month_background_{year}_{month}`)
- 이전 배경 파일 자동 삭제 후 새 파일 적용
- 디폴트 버튼으로 기본 월별 이미지 복원 (파일 삭제 + prefs 제거)

#### 글래스모피즘 헤더
- `BackdropFilter` (`dart:ui.ImageFilter.blur`) + 반투명 흰 배경의 `_glassBox()` 헬퍼
- 좌: 큰 월 숫자 / 우: 연도 + 영문 월명 (FittedBox로 줄임 처리)

#### 반응형 레이아웃 (`_CalendarLayout`)
- `LayoutBuilder`에서 화면 너비로 `_CalendarLayout.from()` 생성
- compact(< 370) / normal / expanded(≥ 430) 3단계 + `lerp()` 선형 보간
- 폰트 크기·패딩·행 높이·패널 높이·액션바 너비 등 28개 속성 통합 관리

### 일정 폼 시트 (`ScheduleFormSheet`) 전면 개편
- `AnimatedPadding` + `viewInsets.bottom`으로 키보드 올라올 때 카드 자동 이동
- 카드 최대 너비 640pt, `compact`(< 390pt) 모드별 내부 여백 분리
- 필드 구성: 제목 / 날짜(표시만) / 기준(양력·음력 세그먼트 토글) / 시간 / 색상 / 반복 / 알림 / 내용
- `_colorSelector()` — 5색 팔레트 원형 선택기 (`AnimatedContainer` + 체크 아이콘)
- `_calendarModeSelector()` — 슬라이딩 세그먼트 컨트롤 (양력/음력)
- `_alarmSelector()` / `_repeatSelector()` — `PopupMenuButton` 드롭다운
- `_formField()` 공통 컨테이너 (라벨 78pt 고정, 외곽선 + 미세 그림자)
- `endTime` / `location` — 모델·DB에는 존재하나 현재 UI에서는 `null`로 저장

### 데이터 모델 확장
- `Schedule`: `endTime`, `location` 필드 추가 / `copyWith` 및 `toMap`/`fromMap` 업데이트
- `Holiday`: `isPublicHoliday`, `isAnniversary` getter 추가 / `insertPriority()` 정적 메서드 추가 / `_priority()` 로직을 모델로 이동
- `DatabaseHelper`: DB v4 → v5 (`end_time TEXT`, `location TEXT` 컬럼 추가, `_onUpgrade` v5 처리)

### 반복 일정 헬퍼 분리
- `lib/core/repeat_schedule_helper.dart` 신규 파일 (`RepeatScheduleHelper` abstract class)
  - `datesInMonth(Schedule, DateTime, CalendarEngine)` — 주어진 달에 반복 일정이 표시될 날짜 키 목록 반환
  - `matchesDay(Schedule, DateTime, CalendarEngine)` — 특정 날짜에 반복 일정 해당 여부 반환
  - `daily` / `monthly`(양력·음력) / `yearly`(양력·음력) 모든 조합 처리

### 파일 삭제
- `lib/features/schedule/day_schedule_sheet.dart` 삭제 — 기능이 `calendar_page.dart` 인라인 패널로 완전 통합됨

---

## V.0.01.100 — 2026-05-12

### 공공데이터포털 API 일원화 완성
- `google_calendar_service.dart` 삭제 — 공공데이터포털 단일 소스로 확정
- `HolidayApiService` 전면 개편:
  - `hasBuildTimeApiKey` getter — 빌드타임 키 존재 여부 동기 확인
  - `getApiKey()` / `saveApiKey()` — `SharedPreferences` 연동 (빌드타임 키 우선)
  - `hasApiKey()` async — 키 존재 여부 비동기 확인
  - `fetchAllSpecialDays(year)` — 기념일·공휴일·국경일·24절기 4개 엔드포인트 병렬 호출
  - `isHoliday == 'Y'` 필터 제거 → 모든 항목 포함, type으로 구분
- `CalendarPage`에 앱 내 API 키 입력 다이얼로그 추가:
  - `_apiKeyPromptShown` 중복 표시 방지 플래그
  - `_ensureHolidayApiKey()` — 빌드타임 키 없을 때 최초 실행 시 한 번만 호출
  - `_showApiKeyDialog()` — `AlertDialog` 기반 입력창 (나중에/저장 버튼)
  - 키 저장 후 올해·내년 데이터 즉시 프리패치
- 달력 표시용 `_calendarHolidays` 맵 분리 (기념일 제외) — 기존 `_holidays`와 이원화

---

## V.0.01.011 — 2026-05-11

### 월별 배경 이미지 + 반응형 레이아웃 기반 구축
- 월별 배경 이미지 12개 추가 (`image/01_JAN.png` ~ `image/12_DEC.png`)
- 앱 아이콘 재교체 (캘린더 디자인 변경)
- pubspec.yaml: Pretendard / Inter / SpaceGrotesk 폰트 등록

#### CalendarPage 개편
- 고정 `_rowHeight`/`_dowHeight` 상수 → `_CalendarLayout` 반응형 레이아웃 초기 도입
- `AnimatedSwitcher` + `SlideTransition` 월 전환 애니메이션 적용
  - `_monthTransitionDirection` 상태로 방향 결정 (+1 다음 달, -1 이전 달)
  - `_monthPageKey` (`연도-월`) 기반 `ValueKey`로 위젯 교체 트리거
- `SingleChildScrollView` 기반 스크롤 구조로 전환
- `_buildHeroBackground()` — 월별 이미지 히어로 배경 (하단 라운드 클립)
- 스와이프 액션바 1차 구현 (`_buildSwipeActionBar`) — `BAR.png` 이미지 기반
- `_monthNames` 영문 배열, `_monthImages` 경로 배열 추가
- `precacheImage` 이미지 프리캐싱 (`initState`)

#### main.dart
- `deferFirstFrame` / `allowFirstFrame` 적용 — 1초 splash 후 첫 프레임 허용

#### 문서 현행화
- `HISTORY.md`, `README.md`, `doc/current_design.md`, `CLAUDE.md` 전면 갱신

---

## V.0.00.700 — 2026-05-09

### 폰트 / 패키지 / 반복 일정 인프라

#### 폰트 추가
- Pretendard Variable / Inter Variable / SpaceGrotesk 폰트 파일 추가 (`fonts/`)

#### 패키지 추가
- `flutter_slidable: ^3.1.1` — 일정 아이템 슬라이드 액션
- `image_picker: ^1.2.2` — 갤러리 사진 선택
- `path_provider: ^2.1.5` — 앱 문서 디렉터리 경로 조회
- `flutter_launcher_icons: ^0.14.3` — 앱 아이콘 자동 생성

#### DatabaseHelper
- `getAllRepeatSchedules()` 추가 — `repeat_type IS NOT NULL` 전체 조회
- `clearHolidaysByYear(year)` 추가 — 연도별 공휴일 강제 삭제 (갱신 전 사용)

#### CalendarPage
- Google Calendar API + 공공데이터포털 병행 구조 (`_googleService` + `_apiService`)
- `_loadSchedules()`: 비반복 일정 + `getAllRepeatSchedules()` 기반 Dot 마커 집계 개선
- Slidable 일정 아이템 첫 적용
- 월별 배경 이미지 SharedPreferences 저장 기반 초기 설계

#### ScheduleFormSheet
- 카드형 UI 전면 개편 (흰 카드 + 그림자 + 둥근 모서리)

---

## V.0.00.530 — 2026-05-07

### 앱 아이콘 적용
- Android / iOS 앱 아이콘 교체 (`flutter_launcher_icons` 빌드 결과물 반영)

---

## V.0.00.521 — 2026-05-07

### 앱 아이콘 소스 추가
- `calendar_app_icon.png` 아이콘 원본 파일 추가

---

## V.0.00.520 — 2026-05-11

### 공공데이터포털 특일 API 확장
- 공공데이터포털 인증키를 `--dart-define=HOLIDAY_API_KEY=...`로 빌드/실행 시 주입하는 흐름으로 변경
- 빌드타임 키가 없을 경우 앱 내부 입력창에서 키를 입력하고 `SharedPreferences`에 저장하는 보조 흐름 유지
- 처음 실행 시 올해와 내년의 기념일, 공휴일, 국경일, 24절기 데이터를 모두 조회하도록 변경
- 월말일에는 다음 달이 속한 연도의 4개 특일 데이터를 강제 갱신하도록 유지
- `HolidayApiService`에 `fetchAllSpecialDays()` 및 4개 엔드포인트별 조회 메서드 추가
- Google Calendar 공휴일 API 서비스를 제거하고 공공데이터포털 기준으로 데이터 소스 일원화
- 같은 날짜에 여러 특일이 겹칠 때 공휴일, 24절기, 국경일, 기념일 순으로 우선 표시
- 인증키가 포함된 `doc/openapi.txt`를 커밋하지 않도록 `.gitignore`에 추가
- 기념일은 달력 셀에서 제외하고 선택 날짜 하단 정보창에서만 표시하도록 분리

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
