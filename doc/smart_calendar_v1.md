📅 스마트 하이브리드 달력 앱 설계서 (v1.2)

본 문서는 음력·양력 병행 표기, 한국 특화 데이터(휴일, 절기), 그리고 스마트 알림 시스템을 포함한 플러터(Flutter) 기반 달력 애플리케이션의 최종 상세 설계서입니다.

현행 진행 메모:

- 최신 구현 기준 설계는 `doc/current_design.md`를 우선 참고합니다.
- 기념일, 공휴일, 국경일, 24절기 데이터는 공공데이터포털 한국천문연구원 `특일 정보 조회 서비스` 기준으로 진행합니다.
- API 키는 `--dart-define=HOLIDAY_API_KEY=...`로 주입합니다.
- 빌드타임 키가 없으면 앱 내부 입력창에서 입력하고 앱 내부 저장소에 보관합니다.
- 키가 없을 때에는 특일 연동 없이 음력 표시와 로컬 일정 기능 중심으로 앱을 유지합니다.
- 초기 설계의 Riverpod 적용은 향후 계획이며, 현재 구현은 StatefulWidget 중심입니다.
- 현재 메인 화면은 월별 이미지 히어로, 흰색 카드형 달력, 하단 일정 카드, 좌우 슬라이드 월 전환 애니메이션 구조입니다.

1. 프로젝트 개요

프로젝트명: 전통과 현대가 공존하는 스마트 하이브리드 달력 (Smart Hybrid Calendar)

플랫폼: Flutter (Android, iOS)

핵심 목표:

양력·음력 및 24절기의 정확한 정보 제공.

한국의 법정 공휴일 및 대체 휴일 자동 연동.

사용자 편의성을 극대화한 일정 등록 및 스마트 푸시 알림.

AI와의 모듈형 협업을 통한 효율적인 개발.

2. 핵심 기능 상세 설계

2.1. 하이브리드 캘린더 엔진 (Calendar Engine)

데이터 표기:

양/음력 병기: 양력 날짜를 메인으로 하고, korean_lunar_calendar를 활용해 음력 날짜(월.일)를 작게 표시.

강조: 음력 1일, 15일 및 주요 명절은 별도 색상으로 가독성 확보.

한국 특화 데이터 연동:

공휴일: 공공데이터포털(특일 정보 API) 연동, 대체 공휴일 자동 반영 (Red 색상).

24절기: 입춘, 경칩 등 절기 정보를 해당 날짜 상단에 텍스트 아이콘으로 표시 (Green 색상).

시각화 가이드:

일요일/공휴일: Red

토요일: Blue

평일: Black/White (테마 대응)

2.2. 일정 관리 및 알림 (Schedule & Notification)

일정 관리 (CRUD):

날짜 클릭 시 일정 입력용 BottomSheet 또는 모달 활성화.

구성 요소: 제목, 메모, 시간, 알림 설정(On/Off), 카테고리 색상 선택.

스마트 알림 시스템:

알림 설정: flutter_local_notifications 활용.

알림 시점: 정시, 10분 전, 30분 전, 1시간 전, 하루 전 등 프리셋 제공.

특수 알림: 음력 기념일(생신 등) 리마인드 및 절기 당일 알람 지원.

3. 기술 스택 (Tech Stack)

| 구분 | 기술 제안 | 비고 |
| Framework | Flutter (Dart) | 크로스 플랫폼 (iOS/Android) |
| State Management | Riverpod | 앱 상태 및 비동기 API 데이터 관리 |
| Local Database | sqflite | 일정 저장 및 공휴일 캐싱 |
| UI Components | table_calendar | 커스텀 빌더 기능을 통한 유연한 UI 구현 |
| Notification | flutter_local_notifications | 로컬 푸시 알림 및 스케줄링 |
| External API | 한국천문연구원 특일 정보 API | 공휴일/절기 데이터 소스 |

4. 데이터베이스 설계 (DB Schema)

CREATE TABLE schedules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    memo TEXT,
    solar_date TEXT NOT NULL, -- YYYY-MM-DD
    time TEXT,                -- HH:mm
    is_lunar INTEGER DEFAULT 0, -- 0: 양력, 1: 음력
    alarm_minutes_before INTEGER, -- 알림 시간(분 단위)
    category_color INTEGER DEFAULT 0xFF2196F3
);



5. AI 협업 단계별 로드맵 (AI 프롬프트 가이드)

Step 1: 데이터 모델 및 DB 구현

"플러터에서 sqflite를 사용하여 일정(제목, 메모, 날짜, 시간, 알림 설정)을 저장할 수 있는 모델 클래스와 DB 헬퍼 코드를 작성해 줘."

Step 2: 기본 달력 UI 및 음력 표시

"table_calendar와 korean_lunar_calendar 패키지를 사용하여, 각 날짜 셀에 양력과 음력이 함께 표시되는 커스텀 달력 UI를 만들어 줘."

Step 3: 외부 API 연동 및 휴일 표시

"공공데이터포털 API를 사용하여 한국 공휴일과 24절기 데이터를 가져와서 달력에 반영하는 Service 클래스를 작성해 줘. 가져온 데이터는 DB에 캐싱해서 사용하고 싶어."

Step 4: 일정 등록 및 알림 시스템

"사용자가 날짜를 클릭하면 일정을 등록하는 UI를 만들고, flutter_local_notifications를 사용해 설정한 시간에 알림이 울리도록 구현해 줘. 안드로이드와 iOS 권한 설정도 포함해 줘."

6. UI/UX 및 디자인 가이드

가독성: 양/음력 텍스트 겹침 방지를 위해 Stack 또는 Column 구조 활용.

다크 모드: ThemeData를 활용해 시스템 테마에 자동 대응.

인터랙션:

날짜 롱 프레스: 즉시 일정 추가 화면 진입.

좌우 스와이프: 월 단위 이동.

일정 마커: 일정이 있는 날짜 하단에 작은 점(Dot) 표시.

7. 향후 확장 계획

구글/애플 캘린더 동기화.

홈 화면 위젯 (오늘의 일정 & 음력 날짜).

음력 기념일 매년 반복 알림 최적화.
