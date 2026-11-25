"""SemiCon Campus Guide - 테스트 API (AWS Lambda + Function URL)

반도체 계열 학생을 위한 학사 정보·대외활동 안내 RAG 챗봇의 2주차 테스트 API.
S3 버킷에 저장된 지식 베이스(JSON)를 읽어 조회·키워드 검색 결과를 돌려준다.

GET /             서비스 소개 페이지(HTML)
GET /health       상태 확인(JSON)
GET /academics    학사 정보 목록
GET /activities   대외활동·교육 목록
GET /search?q=    학사 정보 + 대외활동 키워드 검색
"""
import html
import json
import os

import boto3

BUCKET = os.environ.get("DATA_BUCKET", "")
s3 = boto3.client("s3")
_cache = {}


def load(name):
    if name not in _cache:
        obj = s3.get_object(Bucket=BUCKET, Key=f"data/{name}.json")
        _cache[name] = json.loads(obj["Body"].read())
    return _cache[name]


def resp(body, status=200, ctype="application/json; charset=utf-8"):
    if not isinstance(body, str):
        body = json.dumps(body, ensure_ascii=False, indent=2)
    return {"statusCode": status, "headers": {"Content-Type": ctype}, "body": body}


def search(q):
    q = q.strip().lower()
    hits = []
    for name in ("academics", "activities"):
        for item in load(name)["items"]:
            text = " ".join([item.get("title", ""), item.get("summary", ""), " ".join(item.get("tags", []))]).lower()
            if q and q in text:
                hits.append({"source_set": name, **item})
    return hits


def home_page():
    acad, acts = load("academics"), load("activities")
    rows = "".join(
        f"<li><b>{html.escape(a['title'])}</b> <span>{html.escape(a['type'])} · {html.escape(a['period'])}</span></li>"
        for a in acts["items"]
    )
    return f"""<!doctype html><html lang="ko"><head><meta charset="utf-8">
<title>SemiCon Campus Guide</title>
<style>body{{font-family:-apple-system,'Apple SD Gothic Neo','Malgun Gothic',sans-serif;margin:0;background:#f5f7fa;color:#1d2433}}
header{{background:#14213d;color:#fff;padding:28px 40px}}h1{{margin:0 0 6px}}main{{padding:24px 40px}}
.card{{background:#fff;border-radius:10px;padding:18px 22px;margin-bottom:16px;box-shadow:0 1px 3px #0001}}
li{{margin:6px 0}}span{{color:#5b6475;font-size:14px}}code{{background:#eef1f6;padding:2px 6px;border-radius:4px}}</style></head>
<body><header><h1>SemiCon Campus Guide</h1>
<div>반도체 계열 학생을 위한 학사 정보 · 대외활동 안내 챗봇 — 2주차 테스트 API</div></header><main>
<div class="card"><b>상태</b>: 정상 실행 중 (AWS Lambda · ap-northeast-2) &nbsp;|&nbsp; 데이터: S3 <code>{html.escape(BUCKET)}</code>
&nbsp;|&nbsp; 학사 정보 {len(acad['items'])}건 · 대외활동 {len(acts['items'])}건</div>
<div class="card"><b>대외활동 · 교육 목록</b><ul>{rows}</ul></div>
<div class="card"><b>API</b>: <code>/health</code> <code>/academics</code> <code>/activities</code> <code>/search?q=하이닉스</code></div>
</main></body></html>"""


def handler(event, context):
    path = event.get("rawPath", "/")
    params = event.get("queryStringParameters") or {}
    try:
        if path == "/":
            return resp(home_page(), ctype="text/html; charset=utf-8")
        if path == "/health":
            return resp({"status": "ok", "service": "semicon-campus-guide", "bucket": BUCKET,
                         "region": os.environ.get("AWS_REGION")})
        if path == "/academics":
            return resp(load("academics"))
        if path == "/activities":
            return resp(load("activities"))
        if path == "/search":
            q = params.get("q", "")
            hits = search(q)
            return resp({"query": q, "count": len(hits), "results": hits})
        return resp({"error": "not found", "path": path}, 404)
    except Exception as e:  # 테스트 단계: 오류 내용을 그대로 반환
        return resp({"error": str(e)}, 500)
