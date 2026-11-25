#!/bin/bash
# SemiCon Campus Guide - AWS 배포 스크립트 (AWS CloudShell에서 실행)
# 만드는 리소스: S3 버킷(지식 베이스), IAM 역할(최소 권한), Lambda 함수, Lambda Function URL
set -euo pipefail

REGION="${REGION:-ap-northeast-2}"
APP="semicon-campus-guide"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${APP}-${ACCOUNT}"
ROLE="SemiconGuide-LambdaRole"
FUNC="$APP"
TAGS="Project=SemiconGuide Week=Week2"
cd "$(dirname "$0")/.."

echo "== 1. S3 버킷 (지식 베이스 저장소): $BUCKET"
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
fi
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging 'TagSet=[{Key=Project,Value=SemiconGuide},{Key=Week,Value=Week2}]'
aws s3 cp data/ "s3://$BUCKET/data/" --recursive --content-type "application/json; charset=utf-8"

echo "== 2. IAM 역할 (Lambda 실행 + 해당 버킷 data/ 읽기만 허용): $ROLE"
if ! aws iam get-role --role-name "$ROLE" >/dev/null 2>&1; then
  aws iam create-role --role-name "$ROLE" --tags Key=Project,Value=SemiconGuide Key=Week,Value=Week2 \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
  aws iam attach-role-policy --role-name "$ROLE" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  echo "   IAM 역할 전파 대기 (15초)"; sleep 15
fi
aws iam put-role-policy --role-name "$ROLE" --policy-name ReadKnowledgeBase --policy-document \
  "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::$BUCKET/data/*\"}]}"
ROLE_ARN=$(aws iam get-role --role-name "$ROLE" --query Role.Arn --output text)

echo "== 3. Lambda 함수 배포: $FUNC"
rm -f /tmp/$APP.zip && (cd src && zip -q /tmp/$APP.zip app.py)
if aws lambda get-function --function-name "$FUNC" --region "$REGION" >/dev/null 2>&1; then
  aws lambda update-function-code --function-name "$FUNC" --zip-file fileb:///tmp/$APP.zip --region "$REGION" >/dev/null
  aws lambda wait function-updated --function-name "$FUNC" --region "$REGION"
else
  aws lambda create-function --function-name "$FUNC" --runtime python3.12 --handler app.handler \
    --role "$ROLE_ARN" --zip-file fileb:///tmp/$APP.zip --timeout 10 --memory-size 128 \
    --environment "Variables={DATA_BUCKET=$BUCKET}" --tags Project=SemiconGuide,Week=Week2 \
    --region "$REGION" >/dev/null
  aws lambda wait function-active --function-name "$FUNC" --region "$REGION"
fi

echo "== 4. Function URL (공개 HTTPS 엔드포인트)"
if ! aws lambda get-function-url-config --function-name "$FUNC" --region "$REGION" >/dev/null 2>&1; then
  aws lambda create-function-url-config --function-name "$FUNC" --auth-type NONE --region "$REGION" >/dev/null
  aws lambda add-permission --function-name "$FUNC" --statement-id public-url \
    --action lambda:InvokeFunctionUrl --principal "*" --function-url-auth-type NONE --region "$REGION" >/dev/null
  aws lambda add-permission --function-name "$FUNC" --statement-id public-url-invoke \
    --action lambda:InvokeFunction --principal "*" --invoked-via-function-url --region "$REGION" >/dev/null 2>&1 \
    || echo "   (참고) 현재 CLI가 --invoked-via-function-url을 지원하지 않아 InvokeFunctionUrl 권한만 추가했습니다."
fi
URL=$(aws lambda get-function-url-config --function-name "$FUNC" --region "$REGION" --query FunctionUrl --output text)

echo "== 5. 실행 확인"
sleep 3
curl -s "${URL}health"; echo
curl -s -G "${URL}search" --data-urlencode "q=하이닉스" | head -c 400; echo
echo
echo "배포 완료: $URL"
