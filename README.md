# SemiCon Campus Guide

반도체 계열 학생(신소재·반도체공학, 반도체·디스플레이공학, 반도체 다중전공 희망자)을 위한
**학사 정보 종합 + 대외활동·교육 안내 RAG 챗봇** 프로젝트입니다.
한양대 ERICA 클라우드아키텍처 수업의 주차별 실습 과제로 진행합니다.

## 2주차 범위: AWS 환경 및 개발 환경 구성

| 구분 | 구성 |
|---|---|
| 실행 환경 | AWS Lambda (Python 3.12, 서울 리전 ap-northeast-2) + Lambda Function URL |
| 저장소 | Amazon S3 `semicon-campus-guide-<계정ID>` (퍼블릭 차단, SSE-S3 암호화) — 챗봇 지식 베이스 JSON |
| 접근 권한 | IAM 역할 `SemiconGuide-LambdaRole` — CloudWatch Logs 기록 + 해당 버킷 `data/*` 읽기만 허용 |
| 개발 도구 | Claude Code, Git/GitHub, AWS CloudShell(AWS CLI) |

## 구조

```
src/app.py          Lambda 핸들러 (테스트 API)
data/academics.json 학사 정보 지식 베이스
data/activities.json 대외활동·교육 지식 베이스
scripts/deploy.sh   AWS 배포 (S3 → IAM → Lambda → Function URL → 동작 확인)
scripts/cleanup.sh  리소스 정리
CLAUDE.md           Claude Code 작업 안내
```

## API

| 경로 | 설명 |
|---|---|
| `GET /` | 서비스 소개 페이지 (HTML) |
| `GET /health` | 상태 확인 |
| `GET /academics` | 학사 정보 목록 |
| `GET /activities` | 대외활동·교육 목록 |
| `GET /search?q=키워드` | 학사 정보 + 대외활동 통합 키워드 검색 |

## 배포 방법 (AWS CloudShell)

```bash
git clone https://github.com/kyobak/semicon-campus-guide.git
cd semicon-campus-guide
./scripts/deploy.sh      # 마지막 줄에 Function URL 출력
./scripts/cleanup.sh     # 실습 후 정리
```

## 다음 단계 (3주차~)

- 학교 학사 공지·대외활동 공고 수집 파이프라인 (EventBridge 스케줄 + Lambda)
- Amazon Bedrock 임베딩 + 벡터 검색으로 `/search`를 RAG 답변(`/chat`)으로 확장

> 데이터는 2026년 공고 기준 예시이며, 실제 일정은 학교·주최 측 공식 공지를 확인하세요.
