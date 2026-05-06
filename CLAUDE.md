# CLAUDE.md — Smart Hybrid Calendar

## 프로젝트 개요

Flutter 기반 양력/음력 하이브리드 달력 앱. 한국 공휴일·24절기 연동, 일정 CRUD, 스마트 푸시 알림이 핵심 기능이다.

## 아키텍처

- **State Management**: Riverpod (앱 상태 및 비동기 API 데이터)
- **Local DB**: sqflite (`schedules` 테이블 — DB 스키마는 README.md 참고)
- **Calendar UI**: `table_calendar` (커스텀 빌더로 양/음력 셀 구현)
- **Notifications**: `flutter_local_notifications` (Android / iOS 권한 포함)
- **Lunar conversion**: `korean_lunar_calendar`
- **External API**: 공공데이터포털 특일 정보 API → DB 캐싱 후 사용

## 디렉터리 구조 (예정)

```
lib/
  core/
    db/          # sqflite 헬퍼
    api/         # 공공데이터포털 서비스 클래스
  features/
    calendar/    # 달력 UI, 음력 표시 로직
    schedule/    # 일정 CRUD, BottomSheet
    notification/ # 알림 스케줄링
  shared/
    models/      # Schedule, Holiday, SolarTerm 모델
    theme/       # ThemeData (라이트/다크)
```

## 개발 단계 (AI 협업 로드맵)

| Step | 작업 |
|---|---|
| 1 | 데이터 모델 및 sqflite DB 헬퍼 구현 |
| 2 | table_calendar + korean_lunar_calendar 달력 UI |
| 3 | 공공데이터포털 API 연동 및 DB 캐싱 |
| 4 | 일정 등록 UI + flutter_local_notifications 알림 |

## 색상 규칙

```dart
// 반드시 이 규칙을 따를 것
// 일요일 / 공휴일 → Colors.red
// 토요일          → Colors.blue
// 절기            → Colors.green
// 평일            → 테마 기본색 (다크 대응)
```

## 코딩 컨벤션

- Dart 파일명: `snake_case.dart`
- 클래스명: `PascalCase`
- Riverpod Provider는 `*Provider` 또는 `*Notifier` 접미사 사용
- sqflite 쿼리는 DB 헬퍼 클래스 안에만 작성 (UI 레이어에서 직접 쿼리 금지)
- 음력 변환 로직은 `CalendarEngine` 클래스로 격리

## 주요 주의사항

- 공공데이터포털 API 키는 `.env` 또는 `--dart-define`으로 주입, 소스에 하드코딩 금지
- 공휴일·절기 데이터는 연도별로 API 호출 후 sqflite에 캐싱, 앱 재시작 시 캐시 우선 사용
- `flutter_local_notifications` Android 설정 시 `AndroidManifest.xml` 권한(`SCHEDULE_EXACT_ALARM`) 반드시 포함
- iOS 알림은 `UNUserNotificationCenter` 권한 요청 흐름 포함
- 양/음력 텍스트 겹침 방지: 날짜 셀은 `Column` 구조 사용 (Stack 사용 시 overflow 주의)
