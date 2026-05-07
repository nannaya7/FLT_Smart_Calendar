# 스마트 하이브리드 달력 (Smart Hybrid Calendar)

양력·음력 병행 표기, 한국 공휴일·24절기 연동, 일정 CRUD 및 스마트 푸시 알림을 갖춘 Flutter 달력 앱.

**플랫폼**: Flutter (Android / iOS)

---

## 주요 기능

### 하이브리드 달력

- 양력 날짜 메인 표시 + 음력 날짜(월·일) 작게 병기
- 음력 1일·15일 및 주요 명절 강조 표시
- 한국 공휴일(대체 공휴일 포함) 자동 연동 — 빨간색
- 24절기(입춘·경칩 등) 해당 날짜 표시 — 초록색
- 전통 음력 명절(단오·추석 등) 서브텍스트 표시 — 주황색

### 색상 규칙

| 구분 | 색상 |
|---|---|
| 일요일 / 법정 공휴일 | Red `#FF7070` |
| 토요일 | Blue `#70A8FF` |
| 24절기 | Green `#80E080` |
| 음력 명절·특일 서브텍스트 | Orange `#FFAA88` |
| 평일 | White |

### 일정 관리 (CRUD)

- 날짜 탭 → 하단 인라인 패널에서 일정 목록 확인 및 추가
- 패널 헤더에 양력·음력 날짜 동시 표기, 절기·명절 서브텍스트 표시
- 일정 항목: 제목, 메모, 시간, 알림 설정, 반복 유형, 양력/음력 구분
- 스와이프(→←)로 일정 삭제
- 일정 있는 날짜에 Dot 마커 표시 (최대 3개)

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
| External API | 공공데이터포털 한국천문연구원 특일 정보 API | — |

---

## 프로젝트 구조

```
lib/
  core/
    calendar_engine.dart          # 음력 변환 및 명절 판별 (CalendarEngine)
    api/
      holiday_api_service.dart    # 공공데이터포털 API 래퍼
    db/
      database_helper.dart        # sqflite CRUD (schedules + holidays)
    notifications/
      notification_service.dart   # 알림 초기화 및 스케줄링
  features/
    calendar/
      calendar_page.dart          # 메인 달력 UI + 인라인 일정 패널
    schedule/
      schedule_form_sheet.dart    # 일정 등록 BottomSheet
  shared/
    models/
      schedule.dart               # 일정 모델
      holiday.dart                # 공휴일·절기 모델
  main.dart
```

---

## DB 스키마 (v4)

```sql
CREATE TABLE schedules (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    title                 TEXT    NOT NULL,
    memo                  TEXT,
    solar_date            TEXT    NOT NULL,   -- YYYY-MM-DD (양력 기준)
    time                  TEXT,               -- HH:mm
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
    type  TEXT NOT NULL   -- 'holiday' | 'solar_term'
);
```

---

## 실행 방법

API 키는 소스에 하드코딩하지 않고 `--dart-define`으로 주입합니다.

```bash
flutter run --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
```

API 키 없이 실행하면 공휴일·절기 API 호출을 건너뛰고 음력 데이터만 표시됩니다.

---

## 향후 계획

- 일정 편집 기능 (현재 추가·삭제만 지원)
- Riverpod 상태 관리 적용
- 라이트/다크 테마 전환 (`shared/theme/`)
- 홈 화면 위젯 (오늘 일정 & 음력 날짜)
- 구글·애플 캘린더 동기화
