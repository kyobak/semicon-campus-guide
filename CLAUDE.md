# CLAUDE.md

반도체 계열 학생용 학사 정보·대외활동 안내 RAG 챗봇(SemiCon Campus Guide).

- 런타임: AWS Lambda Python 3.12, 리전 ap-northeast-2. 외부 패키지 없이 boto3만 사용한다.
- 지식 베이스는 `data/*.json`이며 배포 시 S3 `semicon-campus-guide-<계정ID>/data/`로 올라간다.
  새 항목은 `id, title, summary, tags, source` 필드를 반드시 채우고, 출처 URL이 없는 정보는 넣지 않는다.
- 배포는 `scripts/deploy.sh`, 정리는 `scripts/cleanup.sh`. IAM 권한은 최소 권한 원칙을 유지한다.
- 로컬 확인: boto3를 가짜 S3로 대체해 `src/app.handler`에 `{"rawPath": "/health"}` 이벤트를 넣어 본다.
