# 스마트 하이브리드 달력 현행 설계서

작성일: 2026-05-11

## 1. 프로젝트 개요

스마트 하이브리드 달력은 Flutter 기반 Android/iOS 달력 앱이다. 양력 날짜를 기본으로 표시하면서 음력 날짜, 한국 전통 명절, 법정 공휴일, 대체 공휴일, 24절기, 사용자 일정을 함께 보여주는 것을 목표로 한다.

현재 구현은 로컬 중심 앱 구조이며, 일정 데이터와 공휴일/절기 캐시는 기기 내 sqflite DB에 저장한다.
메인 화면은 월별 배경 이미지 히어로, 흰색 달력 카드, 하단 일정 카드로 구성한다.

## 2. 현재 진행 방향

- 공휴일과 24절기 데이터는 공공데이터포털 한국천문연구원 `특일 정보 조회 서비스` 기준으로 진행한다.
- 공공데이터포털 API 키는 아직 발급 전이다.
- API 키가 없을 때도 앱은 정상 실행되어야 한다.
- API 키 미주입 상태에서는 공휴일/24절기 API 호출을 건너뛰고, 음력 표시와 로컬 일정 기능 중심으로 동작한다.
- API 키 발급 후 `--dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>` 방식으로 주입한다.

## 3. 핵심 기능

### 3.1 하이브리드 달력

- 양력 날짜를 날짜 셀의 메인 텍스트로 표시한다.
- 각 날짜에 음력 월/일을 함께 표시한다.
- 음력 1일, 15일은 별도 색상으로 강조한다.
- 전통 음력 명절을 날짜 셀 서브텍스트로 표시한다.
- 공공데이터포털 연동 후 법정 공휴일과 대체 공휴일을 표시한다.
- 공공데이터포털 연동 후 24절기를 표시한다.
- 월 이동 시 이전/다음 방향에 맞춰 좌우 슬라이드 애니메이션을 적용한다.

### 3.2 일정 관리

- 날짜 선택 시 하단 인라인 패널에 해당 날짜의 일정 목록을 표시한다.
- 일정 추가/수정을 BottomSheet에서 처리한다.
- 일정 삭제와 수정은 일정 아이템의 슬라이드 액션으로 처리한다.
- 일정 항목은 제목, 메모, 시간, 알림 설정, 반복 유형, 양력/음력 여부를 가진다.
- 일정이 있는 날짜는 날짜 셀에 Dot 마커를 표시한다.

### 3.3 반복 일정

- 반복 없음, 매일, 매월, 매년을 지원한다.
- 양력 반복 일정은 저장된 양력 날짜를 기준으로 확장 표시한다.
- 음력 반복 일정은 저장 시 음력 월/일을 보존한다.
- 음력 매년 반복 일정은 해당 연도의 음력 날짜를 양력으로 환산해 표시한다.

### 3.4 알림

- `flutter_local_notifications`로 로컬 푸시 알림을 예약한다.
- 알림 시점은 정시, 10분 전, 30분 전, 1시간 전, 하루 전을 지원한다.
- 매일 반복은 `DateTimeComponents.time`을 사용한다.
- 매월 반복은 `DateTimeComponents.dayOfMonthAndTime`을 사용한다.
- 매년 반복 알림은 플러그인 제약상 단발 알림으로 처리한다.

## 4. 기술 스택

| 구분 | 기술 |
|---|---|
| Framework | Flutter / Dart |
| State Management | 현재 StatefulWidget 중심, Riverpod은 향후 적용 후보 |
| Local DB | sqflite |
| Calendar UI | table_calendar |
| Lunar Conversion | korean_lunar_utils |
| HTTP Client | http |
| Notifications | flutter_local_notifications |
| Timezone | timezone |
| Local Preferences | shared_preferences |
| External API | 공공데이터포털 한국천문연구원 특일 정보 API |
| Text Scaling | `TextScaler.noScaling`으로 앱 전체 텍스트 스케일 고정 |

## 5. 디렉터리 구조

```text
smart_calendar/lib/
  main.dart
  core/
    calendar_engine.dart
    api/
      holiday_api_service.dart
      google_calendar_service.dart
    db/
      database_helper.dart
    notifications/
      notification_service.dart
  features/
    calendar/
      calendar_page.dart
    schedule/
      schedule_form_sheet.dart
      day_schedule_sheet.dart
  shared/
    models/
      holiday.dart
      schedule.dart
```

### 구조 메모

- `calendar_page.dart`가 현재 메인 화면과 인라인 일정 패널을 담당한다.
- `schedule_form_sheet.dart`가 일정 추가/수정을 담당한다.
- `day_schedule_sheet.dart`는 이전 BottomSheet 방식 코드로 남아 있으며, 현재 메인 흐름에서는 `calendar_page.dart`의 인라인 패널이 중심이다.
- `google_calendar_service.dart`는 이전 검토용 공휴일 API 래퍼로 남아 있다. 앞으로 공공데이터포털 기준으로 일원화하면서 제거 또는 미사용 처리할 예정이다.

## 6. 데이터 모델

### 6.1 Schedule

일정 모델은 다음 정보를 가진다.

- `id`: DB 기본키
- `title`: 일정 제목
- `memo`: 메모
- `solarDate`: 양력 기준 저장일, `YYYY-MM-DD`
- `time`: 일정 시간, `HH:mm`
- `isLunar`: 음력 일정 여부
- `alarmMinutesBefore`: 알림 선행 시간
- `categoryColor`: 일정 색상
- `repeatType`: `null`, `daily`, `monthly`, `yearly`
- `lunarMonth`: 음력 월
- `lunarDay`: 음력 일

### 6.2 Holiday

공휴일/절기 모델은 다음 정보를 가진다.

- `id`: DB 기본키
- `date`: 양력 날짜, `YYYY-MM-DD`
- `name`: 공휴일 또는 절기 이름
- `type`: `holiday` 또는 `solar_term`

## 7. DB 스키마

현재 DB 버전은 v4다.

```sql
CREATE TABLE schedules (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    title                 TEXT    NOT NULL,
    memo                  TEXT,
    solar_date            TEXT    NOT NULL,
    time                  TEXT,
    is_lunar              INTEGER NOT NULL DEFAULT 0,
    alarm_minutes_before  INTEGER,
    category_color        INTEGER NOT NULL DEFAULT 4280391411,
    repeat_type           TEXT,
    lunar_month           INTEGER,
    lunar_day             INTEGER
);

CREATE TABLE holidays (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    date  TEXT    NOT NULL,
    name  TEXT    NOT NULL,
    type  TEXT    NOT NULL
);
```

## 8. 공휴일/24절기 연동 설계

### 8.1 목표

공휴일과 24절기를 공공데이터포털 한국천문연구원 특일 정보 API로 가져오고, 연도별로 DB에 캐싱한다.

### 8.2 API 키 처리

API 키는 소스에 저장하지 않는다.

```bash
flutter run --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
```

`HOLIDAY_API_KEY`가 비어 있으면 API 서비스는 빈 리스트를 반환한다. 이 경우 앱은 네트워크 오류로 중단되지 않고 음력/일정 기능만 표시한다.

### 8.3 캐싱 정책

- 연도별로 `holidays` 테이블에 저장한다.
- 앱은 먼저 DB 캐시를 확인한다.
- 캐시가 없으면 API를 호출한다.
- 최초 설치 시 올해와 내년 데이터를 미리 가져오는 흐름을 유지한다.
- 월말에는 다음 달 연도의 데이터를 갱신하는 흐름을 유지한다.

## 9. 화면 설계

### 9.1 CalendarPage

메인 화면은 월 배경 이미지 히어로 위에 달력과 하단 일정 패널을 배치한다.

- 상단: 큰 월 숫자, 연도, 영문 월명 헤더
- 중앙: `TableCalendar` 기반 흰색 카드형 달력
- 하단: 선택 날짜의 일정 패널 카드
- 푸터: 짧은 응원 문구

날짜 셀에는 다음 요소를 표시한다.

- 양력 날짜
- 일정 Dot 마커
- 공휴일/절기/음력 명절/음력 날짜 중 하나의 서브텍스트

표시 우선순위는 API 데이터, 음력 명절, 음력 날짜 순서다.
순수 음력 날짜는 `음` 접두어 없이 월·일만 표시한다.

월 전환은 blur/fade 대신 좌우 슬라이드 애니메이션을 사용한다.

- 다음 달: 오른쪽에서 들어옴
- 이전 달: 왼쪽에서 들어옴
- 화면 key는 `연도-월` 기준으로 관리한다.

기기별 폰트 차이를 줄이기 위해 `MaterialApp.builder`에서 `TextScaler.noScaling`을 적용한다.

### 9.2 ScheduleFormSheet

일정 추가/수정 BottomSheet다.

- 양력/음력 모드 선택
- 제목 입력
- 메모 입력
- 시간 선택
- 알림 프리셋 선택
- 반복 유형 선택
- 저장/취소

## 10. 색상 규칙

| 구분 | 색상 |
|---|---|
| 일요일 / 법정 공휴일 | Red |
| 토요일 | Blue |
| 24절기 | Green |
| 음력 명절·특일 서브텍스트 | Orange |
| 평일 | 기본 텍스트 색상 |
| 선택 날짜 | Light Blue 계열 배경 |
| 반복 아이콘 | Purple 계열 |
| 음력 배지 | Amber 계열 |

## 11. 현재 주의사항

- README 기준으로는 문서가 현행화되었지만, 코드에는 아직 Google Calendar 공휴일 서비스가 남아 있다.
- 공공데이터포털 API 키 발급 후 실제 응답 구조와 서비스 키 인코딩 방식을 확인해야 한다.
- 공휴일과 24절기가 같은 날짜에 겹칠 경우 현재 `Map<String, Holiday>` 구조는 하나만 보존할 수 있다. 복수 이벤트 표시가 필요하면 `Map<String, List<Holiday>>` 구조를 검토한다.
- 음력 윤달 처리는 현재 명시 모델이 없다. 윤달 일정까지 지원할 경우 `isLeapMonth` 같은 필드가 필요할 수 있다.
- 월별 이미지, 달력 행 높이, 양력/음력 텍스트 간격은 iPhone / iPhone Pro Max 실기기 화면을 보며 계속 미세 조정한다.

## 12. 다음 작업

1. 공공데이터포털 API 키 발급
2. `holiday_api_service.dart`로 공휴일과 24절기를 모두 조회하도록 정리
3. `google_calendar_service.dart` 제거 또는 미사용 처리
4. API 응답을 실제 키로 검증
5. 공휴일/절기 중복 표시 구조 검토
6. 주요 iPhone 화면 크기별 달력 카드 높이와 일정 카드 위치 추가 검증
