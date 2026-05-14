# AGENTS.md — Smart Hybrid Calendar

## 프로젝트 개요

Flutter 기반 양력/음력 하이브리드 달력 앱. 한국 공휴일·24절기 연동, 일정 CRUD, 스마트 푸시 알림이 핵심 기능이다.

## 아키텍처

- **State Management**: 현재 `StatefulWidget` 중심. Riverpod은 향후 적용 후보
- **Local DB**: sqflite (`schedules` 테이블 — DB 스키마는 README.md 참고)
- **Calendar UI**: `table_calendar` (커스텀 빌더로 양/음력 셀 구현)
- **Notifications**: `flutter_local_notifications` (Android / iOS 권한 포함)
- **Lunar conversion**: `korean_lunar_utils`
- **External API**: 공공데이터포털 한국천문연구원 특일 정보 API → DB 캐싱 후 사용
- **API Key Status**: `--dart-define=HOLIDAY_API_KEY=...` 우선. 빌드타임 키가 없으면 앱 내부 입력창에서 `SharedPreferences`에 저장. 키가 없으면 특일 연동 없이 앱이 동작해야 함
- **Text Scaling**: 기기별 텍스트 크기 차이를 줄이기 위해 `TextScaler.noScaling` 적용

## 디렉터리 구조

```
lib/
  core/
    db/              # sqflite 헬퍼
    api/             # 공공데이터포털 서비스 클래스
    notifications/   # 알림 스케줄링
  features/
    calendar/        # 달력 UI, 음력 표시 로직, 인라인 일정 패널
    schedule/        # 일정 추가/수정 BottomSheet
  shared/
    models/          # Schedule, Holiday 모델
```

## 개발 단계 (AI 협업 로드맵)

| Step | 작업 |
|---|---|
| 1 | 데이터 모델 및 sqflite DB 헬퍼 구현 |
| 2 | table_calendar + korean_lunar_utils 달력 UI |
| 3 | 공공데이터포털 API 연동 및 DB 캐싱 |
| 4 | 일정 등록/수정 UI + flutter_local_notifications 알림 |

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
- Riverpod 도입 시 Provider는 `*Provider` 또는 `*Notifier` 접미사 사용
- sqflite 쿼리는 DB 헬퍼 클래스 안에만 작성 (UI 레이어에서 직접 쿼리 금지)
- 음력 변환 로직은 `CalendarEngine` 클래스로 격리

## 주요 주의사항

- 앞으로 공휴일·24절기 데이터 소스는 공공데이터포털로 일원화한다
- API 키는 `--dart-define=HOLIDAY_API_KEY=...`로 주입하고, 소스에 하드코딩 금지
- 빌드타임 키가 없을 때만 앱 내부 입력창에서 입력받는다
- API 키가 없을 때도 앱은 음력 표시와 로컬 일정 기능으로 정상 동작해야 한다
- 기념일, 공휴일, 국경일, 24절기은 모두 공공데이터포털 특일 정보 API에서 가져온다
- 특일 데이터는 연도별로 API 호출 후 sqflite에 캐싱, 앱 재시작 시 캐시 우선 사용
- 인증키가 포함된 로컬 파일(`doc/openapi.txt`)은 커밋하지 않는다
- `flutter_local_notifications` Android 설정 시 `AndroidManifest.xml` 권한(`SCHEDULE_EXACT_ALARM`) 반드시 포함
- iOS 알림은 `UNUserNotificationCenter` 권한 요청 흐름 포함
- 양/음력 텍스트 겹침 방지: 날짜 셀은 `Column` 구조 사용 (Stack 사용 시 overflow 주의)
- 메인 달력 UI는 월별 이미지 히어로 + 흰색 카드형 달력 + 일정 카드 구조를 유지한다
- 날짜 셀의 양력/음력 폰트와 간격은 작은 iPhone과 Pro Max에서 모두 확인한다
- 월 전환 애니메이션은 이전/다음 방향에 맞춘 좌우 슬라이드 방식을 사용한다
