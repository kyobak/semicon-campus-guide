#!/bin/bash
# SemiCon Campus Guide - 리소스 정리 스크립트
set -uo pipefail
REGION="${REGION:-ap-northeast-2}"
APP="semicon-campus-guide"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="${APP}-${ACCOUNT}"
ROLE="SemiconGuide-LambdaRole"

aws lambda delete-function-url-config --function-name "$APP" --region "$REGION"
aws lambda delete-function --function-name "$APP" --region "$REGION"
aws iam delete-role-policy --role-name "$ROLE" --policy-name ReadKnowledgeBase
aws iam detach-role-policy --role-name "$ROLE" --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam delete-role --role-name "$ROLE"
aws s3 rm "s3://$BUCKET" --recursive
aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION"
echo "정리 완료"
