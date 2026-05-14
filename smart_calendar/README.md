# smart_calendar

Flutter 기반 스마트 하이브리드 달력 앱입니다.

## 현재 기능

- 양력/음력 병행 표시
- 한국 전통 음력 명절 표시
- 월별 이미지 히어로 + 흰색 카드형 달력 UI
- 좌우 슬라이드 월 전환 애니메이션
- 일정 추가/수정/삭제
- 반복 일정: 매일, 매월, 매년
- 로컬 푸시 알림
- 기념일/공휴일/국경일/24절기 DB 캐싱 구조
- iOS 기기별 텍스트 크기 차이를 줄이기 위한 고정 텍스트 스케일

## 공휴일/24절기 API

기념일, 공휴일, 국경일, 24절기 데이터는 공공데이터포털 한국천문연구원 `특일 정보 조회 서비스` 기준으로 진행합니다.
API 키는 빌드 또는 실행 시 `--dart-define`으로 주입합니다.

```bash
flutter run --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
flutter build ios --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
flutter build apk --dart-define=HOLIDAY_API_KEY=<공공데이터포털_API_키>
```

빌드타임 키가 없으면 앱 최초 실행 시 입력창에서 입력하고, 앱 내부 저장소에 보관합니다.

API 키 없이 실행하면 공휴일·절기 API 호출은 건너뛰고 음력 표시와 로컬 일정 기능 중심으로 동작합니다.
ㅇㅏ이코