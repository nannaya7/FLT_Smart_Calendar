# 스마트 하이브리드 달력 현행 설계서

작성일: 2026-05-14 / 최종 수정: 2026-05-21

## 1. 프로젝트 개요

Flutter 기반 Android/iOS 달력 앱. 양력 날짜를 기본으로 표시하면서 음력 날짜, 한국 전통 명절, 법정 공휴일, 대체 공휴일, 24절기, 사용자 일정을 함께 보여준다.

로컬 중심 앱 구조. 일정 데이터와 공휴일/절기 캐시는 기기 내 sqflite DB에 저장한다.
공휴일/24절기 소스는 공공데이터포털 한국천문연구원 `특일 정보 조회 서비스`로 일원화되어 있다.

## 2. 공공데이터포털 API 정책

- API 키는 빌드/실행 시 `--dart-define=HOLIDAY_API_KEY=...`로 주입한다.
- 빌드타임 키가 없으면 앱 최초 실행 시 내부 입력창에서 키를 입력하고 `SharedPreferences`에 저장한다.
- API 키가 없을 때도 앱은 정상 실행된다 (음력 표시·로컬 일정 기능만 동작).
- API 키가 있으면 앱 시작 시 올해·내년 데이터를 자동 프리패치한다.

## 3. 핵심 기능

### 3.1 하이브리드 달력

- 양력 날짜(SpaceGrotesk) + 일정 Dot 마커(최대 3개) + 음력·특일 서브텍스트(Inter) 순 Column 구조
- 음력 1일·15일 금색 강조, 전통 음력 명절 주황색 서브텍스트
- 공공데이터포털 기준 공휴일/국경일 빨강, 24절기 초록
- 기념일은 달력 셀에 표시하지 않고 하단 정보 패널에서만 표시
- 월 전환: `AnimatedSwitcher` + `SlideTransition` 좌우 슬라이드 (방향성 반영)

### 3.2 일정 관리

- 날짜 선택 → 하단 인라인 패널에서 목록 확인 및 추가/수정
- `flutter_slidable`로 우측 슬라이드 → 수정(파랑) / 삭제(빨강)
- 음력 일정 배지(금색), 반복 아이콘(보라), 알람 아이콘 표시

### 3.3 반복 일정

- 없음 / 매일 / 매월 / 매년
- `RepeatScheduleHelper`에서 날짜 계산 로직 전담 (`datesInMonth`, `matchesDay`)
- 음력 반복: `lunarMonth` / `lunarDay` 보존 → 매년 해당 음력 날짜의 양력 환산일에 자동 표시

### 3.4 알림

- `flutter_local_notifications` + `timezone` (Asia/Seoul)
- 프리셋: 없음 / 정시 / 10분 전 / 15분 전 / 30분 전 / 1시간 전 / 하루 전
- 매일 반복: `DateTimeComponents.time`
- 매월 반복: `DateTimeComponents.dayOfMonthAndTime`
- 매년 반복: 단발 알림 (플러그인 제약)

### 3.5 월별 배경 이미지

- 기본: `image/01_JAN.png` ~ `image/12_DEC.png` 12장
- 커스텀: `ImagePicker`로 갤러리 사진 선택 → `documents/month_backgrounds/` 저장
- `SharedPreferences` 키 `month_background_{year}_{month}`로 경로 보존
- 이전 파일 자동 삭제, 디폴트 복원 버튼 제공

## 4. 화면 구조

### 4.1 CalendarPage

```
Scaffold
└── AnimatedSwitcher (월 전환 슬라이드)
    └── Container (key = ValueKey("yyyy-M"))
        └── Stack
            ├── _buildHeroBackground()       ← 월별 배경 이미지 (커스텀/기본)
            ├── SafeArea → LayoutBuilder
            │   └── GestureDetector (수직 스와이프 → 액션바 토글)
            │       └── Stack
            │           ├── SingleChildScrollView
            │           │   └── Column
            │           │       ├── _buildHeader()       ← 글래스모피즘 헤더
            │           │       ├── _buildCalendar()     ← 흰 카드 TableCalendar
            │           │       ├── _buildInfoPanel()    ← 인라인 일정 패널
            │           │       └── _buildFooter()       ← 응원 문구
            │           └── _buildSwipeActionBar()       ← 하단 3버튼 액션바
```

#### _buildHeroBackground
- `ClipRRect` (하단 36pt 라운드) + `DecorationImage` (fit: cover, alignment: topCenter)
- 흰색 그라디언트 오버레이 (screen 블렌드)

#### _buildHeader
- `_glassBox()`: `BackdropFilter` (blur 8) + 반투명 흰 배경
- 좌: 큰 월 숫자 (monthNumberFont: 71~91pt lerp)
- 우: 연도 + 영문 월명 (FittedBox 줄임 처리)

#### _buildCalendar
- `TableCalendar` (headerVisible: false, startingDayOfWeek: sunday, sixWeekMonthsEnforced: true)
- `CalendarBuilders`로 커스텀 셀 렌더링:
  - `dowBuilder` → `_DowCell` (MON~SUN 영문, 일요일/토요일 색상)
  - 그 외 → `_CalendarDayCell`

#### _CalendarDayCell
```
Center → Container (dayCellWidth × dayCellHeight)
  decoration: 선택=회색bg, 오늘=파란bg, 외부달=opacity 0.28
  Column (mainAxisAlignment: center)
    Text(양력 숫자, SpaceGrotesk)
    SizedBox(dayDotAreaHeight) → Row(Dot × min(count, 3))
    Text(서브텍스트, Inter)
```
서브텍스트 우선순위: API 특일 > 음력 명절 > 음력 날짜 (1일·15일 금색)

#### _buildInfoPanel
- `Container(height: infoPanelHeight)`, 흰 카드 + 그림자
- 날짜 미선택: 안내 텍스트
- 날짜 선택: 양력·음력 날짜 + 특일명 헤더 + `+ 일정 추가` 버튼 + `ListView`(일정 목록)

#### _ScheduleListItem (Slidable)
- 우측 슬라이드 → 수정(파랑) / 삭제(빨강)
- 카테고리 컬러 원(9pt) + 제목 + 시간·메모 부제목 + 음력 배지 + 반복 아이콘 + 알람 아이콘

#### _buildSwipeActionBar
- `Positioned` (화면 하단, bottom: SafeArea+8)
- `AnimatedSlide` + `AnimatedOpacity`로 숨김/표시
- `AspectRatio(1536/346)` 안에 `BAR.png` + `_BarTapArea` × 3 (앨범 / 일정 / 정보)
- 수직 스와이프 28pt 임계값: 위로 = 표시, 아래로 = 숨김

### 4.2 _MonthlyScheduleSheet

스와이프 액션바 **일정** 버튼으로 호출. `showModalBottomSheet`로 표시.

```
SizedBox(height: size.height * 0.90)   ← 전체 화면의 90%
└── GestureDetector (onHorizontalDragEnd → 탭 또는 달 전환)
    └── Column
        ├── _buildHeader()             ← _month 기준 연·월 표시 + 좌우 화살표 버튼
        ├── _buildTabBar()             ← TabBar (나의 일정 / 공휴일 / 기념일 / 전체)
        ├── Divider
        └── Expanded → TabBarView (NeverScrollableScrollPhysics)
            ├── _buildList(_mySchedules, ...)
            ├── _buildList(_publicHolidays, ...)
            ├── _buildList(_anniversaries, ...)
            └── _buildList(_allItems, ...)
```

#### 탭 분류 기준

| 탭 | 포함 데이터 |
|---|---|
| 나의 일정 | `schedules` 테이블 (비반복 + 반복 헬퍼 기준) |
| 공휴일 | `rest_day`, `national_holiday` + 사잇날 |
| 기념일 | `solar_term`, `anniversary` |
| 전체 | 위 세 탭 합산, 날짜순 정렬 |

#### 사잇날 감지

`_isNonWorking(DateTime)`: 주말이거나 `rest_day`/`national_holiday` 타입 특일이면 `true`.
월 내 모든 주중 평일을 순회하며 전날·다음날이 모두 `_isNonWorking == true`인 날을 사잇날으로 판별.
사잇날은 공휴일·전체 탭에만 추가, 달력 셀에는 표시하지 않음.

#### 스와이프 네비게이션

- 우→좌 (velocity < −300): 다음 탭; 마지막 탭(index 3)에서 → `_changeMonth(1, targetTab: 0)`
- 좌→우 (velocity > 300): 이전 탭; 첫 탭(index 0)에서 → `_changeMonth(-1, targetTab: 3)`
- `_changeMonth` 호출 시 `_month` 갱신, 4개 데이터 리스트 초기화, `_tabController.animateTo(targetTab)`, `_loadItems()` 순 실행

### 4.3 ScheduleFormSheet

```
AnimatedPadding (viewInsets.bottom 키보드 대응)
└── SizedBox(height: screenHeight)
    └── Center → SingleChildScrollView
        └── ConstrainedBox(maxWidth: 640)
            └── Container (흰 카드, radius 24, 그림자)
                └── Column
                    ├── Row (제목 + 닫기 버튼)
                    ├── _formField(제목 TextField)
                    ├── _formField(날짜 표시, 달력 아이콘)
                    ├── _calendarModeSelector()   ← 양력/음력 세그먼트 토글
                    ├── _timeRow()                ← 시간 선택 버튼
                    ├── _colorSelector()          ← 5색 팔레트 원형 선택기
                    ├── _repeatSelector()         ← PopupMenuButton 드롭다운
                    ├── _alarmSelector()          ← PopupMenuButton 드롭다운
                    ├── _formField(내용 TextField, 3줄)
                    └── Row(취소 버튼 | 저장 버튼)
```

- compact 모드: width < 390pt → 내부 여백 20pt (기본 30pt)
- `_formField()`: 라벨 78pt 고정 너비 + 콘텐츠 + 옵션 trailing 아이콘
- `_calendarModeSelector()`: 세그먼트 토글 — 선택된 쪽 흰 배경 + `_accent` 색상
- `_colorSelector()`: 5색 원형 선택기 — 선택 시 체크 아이콘 + AnimatedContainer

## 5. 반응형 레이아웃 (_CalendarLayout)

`LayoutBuilder`에서 화면 너비를 받아 `_CalendarLayout.from(constraints)`로 생성.

```
compact:  width < 370
normal:   370 ≤ width < 430
expanded: width ≥ 430

effectiveWidth = (width - padding*2).clamp(292, contentMaxWidth)
scale = ((effectiveWidth - 292) / (390 - 292)).clamp(0.0, 1.0)
lerp(min, max) = min + (max - min) * scale
```

주요 lerp 값:
| 속성 | min (compact) | max (expanded) |
|---|---|---|
| monthNumberFont | 71pt | 91pt |
| monthNameFont | 27pt | 33pt |
| calendarRowHeight | 58pt | 66pt |
| dayCellWidth | 37pt | 43pt |
| dayNumberFont | 18pt | 22pt |
| daySubFont | 10.5pt | 13pt |

## 6. 기술 스택

| 구분 | 기술 |
|---|---|
| Framework | Flutter / Dart |
| State Management | StatefulWidget 중심, Riverpod은 향후 후보 |
| Local DB | sqflite |
| Calendar UI | table_calendar |
| Lunar Conversion | korean_lunar_utils |
| HTTP Client | http |
| Notifications | flutter_local_notifications |
| Timezone | timezone |
| Slide Actions | flutter_slidable |
| Image Picker | image_picker |
| File Path | path_provider |
| Local Prefs | shared_preferences |
| External API | 공공데이터포털 한국천문연구원 특일 정보 API |
| Fonts | Pretendard / Inter / SpaceGrotesk (Variable) |
| Text Scaling | `TextScaler.noScaling` 앱 전체 고정 |

## 7. 디렉터리 구조

```
smart_calendar/lib/
  main.dart
  core/
    calendar_engine.dart            # 음력 변환 래퍼 (CalendarEngine 싱글톤)
    repeat_schedule_helper.dart     # 반복 일정 날짜 계산 (RepeatScheduleHelper)
    api/
      holiday_api_service.dart      # 공공데이터포털 특일 API 래퍼
    db/
      database_helper.dart          # sqflite CRUD (v5)
    notifications/
      notification_service.dart     # 알림 초기화 및 스케줄링
  features/
    calendar/
      calendar_page.dart            # 메인 화면 (700줄+)
    schedule/
      schedule_form_sheet.dart      # 일정 등록·수정 카드 폼
  shared/
    models/
      holiday.dart                  # Holiday 모델
      schedule.dart                 # Schedule 모델
```

## 8. 데이터 모델

### 8.1 Schedule

| 필드 | 타입 | 설명 |
|---|---|---|
| id | int? | DB PK |
| title | String | 일정 제목 |
| emoji | String? | 이모지 문자 (달력 셀 서브텍스트에 제목 표시 트리거) |
| memo | String? | 메모 |
| solarDate | String | 양력 기준 저장일 (YYYY-MM-DD) |
| time | String? | 시작 시간 (HH:mm) |
| endTime | String? | 종료 시간 (HH:mm) — 현재 미사용 |
| location | String? | 장소 — 현재 미사용 |
| isLunar | bool | 음력 일정 여부 |
| alarmMinutesBefore | int? | 알림 선행 시간 (분) |
| categoryColor | int | 일정 색상 (ARGB) |
| repeatType | String? | null / daily / monthly / yearly |
| lunarMonth | int? | 음력 월 (isLunar=true 일 때) |
| lunarDay | int? | 음력 일 (isLunar=true 일 때) |
| displayOrder | int? | 날짜 내 정렬 순서 (null이면 COALESCE로 999999 취급 → 맨 뒤) |

### 8.2 Holiday

| 필드 | 타입 | 설명 |
|---|---|---|
| id | int? | DB PK |
| date | String | 날짜 (YYYY-MM-DD) |
| name | String | 특일 이름 |
| type | String | anniversary / rest_day / national_holiday / solar_term |

- `isPublicHoliday`: type == 'rest_day'
- `isAnniversary`: type == 'anniversary'
- `insertPriority(map, h)`: 같은 날짜에 우선순위 높은 것만 map에 유지 (rest_day 50 > solar_term 40 > national_holiday 35 > anniversary 20)

## 9. DB 스키마 (v7)

```sql
CREATE TABLE schedules (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    title                 TEXT    NOT NULL,
    emoji                 TEXT,
    memo                  TEXT,
    solar_date            TEXT    NOT NULL,
    time                  TEXT,
    end_time              TEXT,
    location              TEXT,
    is_lunar              INTEGER NOT NULL DEFAULT 0,
    alarm_minutes_before  INTEGER,
    category_color        INTEGER NOT NULL DEFAULT 4280391411,
    repeat_type           TEXT,
    lunar_month           INTEGER,
    lunar_day             INTEGER,
    display_order         INTEGER
);

CREATE TABLE holidays (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    date  TEXT    NOT NULL,
    name  TEXT    NOT NULL,
    type  TEXT    NOT NULL
);
```

마이그레이션 경로:
- v1 → v2: holidays 테이블 생성
- v2 → v3: repeat_type 추가
- v3 → v4: lunar_month, lunar_day 추가
- v4 → v5: end_time, location 추가
- v5 → v6: emoji 추가
- v6 → v7: display_order 추가

## 10. 공휴일/절기 연동

### 엔드포인트

| 엔드포인트 | type | 설명 |
|---|---|---|
| getAnniversaryInfo | anniversary | 기념일 |
| getRestDeInfo | rest_day | 공휴일 (법정 공휴일, 대체 공휴일) |
| getHoliDeInfo | national_holiday | 국경일 |
| get24DivisionsInfo | solar_term | 24절기 |

### 캐싱 정책

1. 앱 시작 시 DB 캐시 확인 → 없으면 API 호출
2. 최초 설치: 올해 + 내년 데이터 프리패치 (`holiday_initialized` flag)
3. 매월 말일: 다음 달이 속한 연도 강제 갱신 (`holiday_refreshed_{year}_{month}` flag)
4. 달력 셀용(`_calendarHolidays`)과 정보 패널용(`_holidays`) 맵을 분리 — 기념일은 정보 패널에서만 표시

## 11. 색상 규칙

| 구분 | 색상 코드 |
|---|---|
| 일요일 / 법정 공휴일 날짜 숫자 | `#FF3B30` |
| 토요일 날짜 숫자 | `#2E73D8` |
| 공휴일·국경일 서브텍스트 | `#FF6E4A` |
| 24절기 서브텍스트 | `#4FA96A` |
| 음력 명절 서브텍스트 | `#FF6E4A` |
| 음력 1일·15일 서브텍스트 | `#B8920A` (금색) |
| 음력 일반 서브텍스트 | `#656B75` |
| 오늘 배경 | `#EAF2FF` |
| 선택일 배경 | `#EDEEF5` |
| 일정 Dot 마커 | `#3678CF` |
| 음력 배지 배경 | `#B8920A` 15% 투명 |
| 반복 아이콘 | `#8B7CB8` |
| 알람 아이콘 | `#AA9898` |

### 일정 카테고리 팔레트 (5색)

| 색상 | 코드 |
|---|---|
| 핑크 | `#FF8999` |
| 그린 | `#83C8AA` |
| 퍼플 | `#B48BD0` |
| 오렌지 | `#E9B174` |
| 블루 | `#8CB4E8` |

## 12. 현재 미완성/보류 항목

- `endTime` / `location` — 모델·DB 준비됨, UI 폼에서는 아직 `null`로 저장

## 13. 다음 작업 후보

1. 스와이프 액션바 정보 버튼 기능 구현 (설정, API 키 재입력 등)
2. 일정 폼에 종료 시간 / 장소 필드 UI 추가
3. 반복 일정 삭제 시 단일 삭제 vs 전체 삭제 선택 UI
4. 공휴일 API 응답 실기기 검증
5. 음력 윤달 처리 (`isLeapMonth` 필드 검토)
6. Riverpod 상태 관리 전환
