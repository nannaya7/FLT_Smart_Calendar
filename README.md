# 스마트 하이브리드 달력 (Smart Hybrid Calendar)

양력·음력 병행 표기, 한국 공휴일·24절기 연동, 일정 CRUD 및 스마트 푸시 알림을 갖춘 Flutter 달력 앱.

**플랫폼**: Flutter (Android / iOS)

---

## 주요 기능

### 하이브리드 달력

- 월별 배경 이미지 히어로 + 흰색 카드형 달력 UI
- 상단에 큰 월 숫자, 연도, 영문 월명 표시
- 양력 날짜 메인 표시 + 음력 날짜(월·일) 병기
- 음력 1일·15일 및 주요 명절 강조 표시
- 한국 공휴일(대체 공휴일 포함) 자동 연동 — 빨간색
- 24절기(입춘·경칩 등) 해당 날짜 표시 — 초록색
- 전통 음력 명절(단오·추석 등) 서브텍스트 표시 — 주황색
- 기념일은 달력 셀에는 숨기고 선택 날짜 정보창에서만 표시
- 월 전환 시 이전/다음 방향에 맞춘 좌우 슬라이드 애니메이션

### 색상 규칙

| 구분 | 색상 |
|---|---|
| 일요일 / 법정 공휴일 | Red `#FF7070` |
| 토요일 | Blue `#70A8FF` |
| 24절기 | Green `#80E080` |
| 음력 명절·특일 서브텍스트 | Orange `#FFAA88` |
| 평일 | White |
| 선택 날짜 | Light Blue 계열 배경 |

### 일정 관리 (CRUD)

- 날짜 탭 → 하단 인라인 패널에서 일정 목록 확인 및 추가/수정
- 패널 헤더에 양력·음력 날짜 동시 표기, 절기·명절 서브텍스트 표시
- 일정 항목: 제목, 메모, 시간, 알림 설정, 반복 유형, 양력/음력 구분, 카테고리 색상 (5색)
- 스와이프(→) 액션으로 일정 수정(파랑) / 삭제(빨강)
- 일정 있는 날짜에 Dot 마커 표시 (최대 3개)
- 음력 일정 배지(금색) 및 반복 아이콘(보라) 표시

### 스와이프 액션바

- 화면 전체를 위로 스와이프하면 하단에서 3버튼 바가 올라옴
- 앨범: 현재 달 배경 이미지를 갤러리 사진으로 교체 / 기본 이미지로 초기화
- 일정: 포커스된 달의 공휴일·국경일·절기·기념일·등록 일정을 날짜순으로 표시하는 월간 목록 팝업
- 정보: `splash/app_info.png` 전체 화면 오버레이 표시 (탭으로 닫기)

### 화면 표시 안정화

- iOS 기기별 텍스트 크기 설정 차이를 줄이기 위해 앱 전체에 `TextScaler.noScaling` 적용
- iPhone / iPhone Pro Max 화면에서 날짜 셀 폰트, 간격, 잘림 여부를 비교하며 조정
- 날짜 셀 안의 양력/음력 폰트 조절 위치에 코드 주석 추가

### 반복 일정

- 매일 / 매월 / 매년 반복 지원
- **음력 매년 반복**: 저장 시 음력 월·일 기록 → 매년 해당 음력 날짜의 양력 환산일에 자동 표시
- 일정 아이템에 음력 배지(amber) 및 반복 아이콘(purple) 표시

### 스마트 알림

- `flutter_local_notifications` 기반 로컬 푸시 알림
- 알림 시점 프리셋: 정시 / 10분 전 / 30분 전 / 1시간 전 / 하루 전
- 반복 알림: 매일(`time`), 매월(`dayOfMonthAndTime`) — 매년은 단발 알림
- Android 13+ 권한 요청 자동 처리
- iOS `UNUserNotificationCenter` 권한 요청 포함

---

## 기술 스택

| 구분 | 기술 | 버전 |
|---|---|---|
| Framework | Flutter (Dart) | SDK ^3.11.5 |
| Local DB | sqflite | ^2.4.2 |
| Calendar UI | table_calendar | ^3.1.2 |
| Lunar Conversion | korean_lunar_utils | ^1.0.1 |
| HTTP Client | http | ^1.2.0 |
| Notifications | flutter_local_notifications | ^18.0.0 |
| Timezone | timezone | ^0.9.4 |
| Slide Actions | flutter_slidable | ^3.1.1 |
| Image Picker | image_picker | ^1.2.2 |
| File Path | path_provider | ^2.1.5 |
| Local Prefs | shared_preferences | ^2.3.4 |
| External API | 공공데이터포털 한국천문연구원 특일 정보 API | `HOLIDAY_API_KEY` |
| Fonts | Pretendard / Inter / SpaceGrotesk | Variable |

---

## 프로젝트 구조

현행 설계서는 [`doc/current_design.md`](doc/current_design.md)를 참고합니다.

```
lib/
  core/
    calendar_engine.dart          # 음력 변환 및 명절 판별 (CalendarEngine)
    repeat_schedule_helper.dart   # 반복 일정 날짜 계산 헬퍼 (RepeatScheduleHelper)
    api/
      holiday_api_service.dart    # 공공데이터포털 특일 정보 API 래퍼
    db/
      database_helper.dart        # sqflite CRUD (schedules + holidays)
    notifications/
      notification_service.dart   # 알림 초기화 및 스케줄링
  features/
    calendar/
      calendar_page.dart          # 메인 달력 UI — 히어로 배경·글래스 헤더·반응형 레이아웃·스와이프 액션바·인라인 일정 패널
    schedule/
      schedule_form_sheet.dart    # 일정 등록·수정 카드형 BottomSheet
  shared/
    models/
      schedule.dart               # 일정 모델 (endTime, location 포함)
      holiday.dart                # 공휴일·절기 모델 (insertPriority 우선순위 관리)
  main.dart
```

---

## DB 스키마 (v5)

```sql
CREATE TABLE schedules (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    title                 TEXT    NOT NULL,
    memo                  TEXT,
    solar_date            TEXT    NOT NULL,   -- YYYY-MM-DD (양력 기준)
    time                  TEXT,               -- HH:mm
    end_time              TEXT,               -- HH:mm (종료 시간, 미사용)
    location              TEXT,               -- 장소 (미사용)
    is_lunar              INTEGER DEFAULT 0,  -- 0: 양력, 1: 음력
    alarm_minutes_before  INTEGER,
    category_color        INTEGER DEFAULT 0xFF2196F3,
    repeat_type           TEXT,               -- null | 'daily' | 'monthly' | 'yearly'
    lunar_month           INTEGER,            -- is_lunar=1 일 때 음력 월
    lunar_day             INTEGER             -- is_lunar=1 일 때 음력 일
);

CREATE TABLE holidays (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    date  TEXT NOT NULL,  -- YYYY-MM-DD
    name  TEXT NOT NULL,
    type  TEXT NOT NULL   -- anniversary | rest_day | national_holiday | solar_term
);
```

---

## 실행 방법

공휴일과 24절기는 공공데이터포털 한국천문연구원 특일 정보 API 기준으로 진행합니다.
API 키는 소스에 하드코딩하지 않습니다. 빌드 또는 실행 시 `--dart-define=HOLIDAY_API_KEY=...`로 공공데이터포털 일반 인증키를 주입합니다.

```bash
flutter run --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
flutter build ios --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
flutter build apk --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
```

빌드타임 키가 없으면 앱 최초 실행 시 입력창에서 키를 등록할 수 있습니다.

API 키 없이 실행하면 특일 API 호출을 건너뛰고 음력 데이터와 로컬 일정 기능만 표시됩니다.

### 공공데이터포털 진행 메모

- 대상 API: 공공데이터포털 `특일 정보 조회 서비스`
- 제공 기관: 한국천문연구원
- 사용 데이터: 기념일, 공휴일, 국경일, 24절기
- 조회 엔드포인트: `getAnniversaryInfo`, `getRestDeInfo`, `getHoliDeInfo`, `get24DivisionsInfo`
- 캐싱 방식: 연도별 조회 후 `holidays` 테이블에 저장
- API 키 등록: `--dart-define=HOLIDAY_API_KEY=...` 우선, 앱 내부 입력은 보조 방식

---

## 향후 계획

- `endTime` / `location` 필드 UI 노출 (종료 시간, 장소)
- Riverpod 상태 관리 적용
- 라이트/다크 테마 전환 (`shared/theme/`)
- 홈 화면 위젯 (오늘 일정 & 음력 날짜)
- 외부 캘린더 동기화
