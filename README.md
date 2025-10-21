# SystemWatch

Shell Script 기반 시스템 모니터링 도구

---

## 프로젝트 소개

리눅스 시스템의 CPU, 메모리, 디스크 사용률을 실시간으로 모니터링하고 HTML 리포트를 생성하는 도구입니다.
임계값 초과 시 이메일 알림을 발송하며, 히스토리 데이터를 CSV 파일로 저장합니다.


---

## 기술 스택
- Shell Script
- Linux
- SMTP(ssmtp)

---

## 프로젝트 구조
SystemWatch/  
├── runner.sh                      # 메인 실행 파일  
├── reports/  
│   ├── system_status.html        # HTML 리포트  
│   └── history/  
│       └── history.csv           # 히스토리 데이터  
└── logs/  
    ├── email_log.txt             # 이메일 발송 로그  
    └── failed_email_log.txt      # 실패한 이메일 백업  

---

## 주요 기능

- 실시간 모니터링: CPU, 메모리, 디스크 사용률 체크 (기본 60초 간격)
- 상태 판정: GOOD / WARNING / CRITICAL 3단계 구분
- HTML 리포트: 웹 브라우저로 확인 가능한 시각화 리포트
- 이메일 알림: 임계값 초과 시 SMTP 이메일 자동 발송
- 히스토리 기록: CSV 파일로 데이터 누적 저장
- 프로세스 모니터링: CPU/메모리 사용량 상위 5개 프로세스 추적
- 좀비 프로세스 감지: 좀비 프로세스 개수 확인

---

## 요구사항
- Linux/Unix 환경
- Bash 4.0 이상
- SSmtp 2.64 이상

---

## 실행 방법
# 1. 실행 권한
chmod +x runner.sh

# 2. 테스트 실행
./runner.sh
