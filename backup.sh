#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

s3() {
    aws s3 --region "$AWS_REGION" "$@"
}

ensure_bucket_exists() {
    echo "Checking access to S3 bucket: $S3_BUCKET_NAME in region $AWS_REGION..."

    aws s3api head-bucket \
        --bucket "$S3_BUCKET_NAME" \
        --region "$AWS_REGION"

    echo "Bucket exists and is accessible."
}

pg_dump_database() {
    pg_dump \
        --no-owner \
        --no-privileges \
        --clean \
        --if-exists \
        --quote-all-identifiers \
        "$DATABASE_URL"
}

upload_to_bucket() {
    s3 cp - \
        "s3://$S3_BUCKET_NAME/$(date +%Y/%m/%d/backup-%H-%M-%S.sql.gz)"
}

main() {
    ensure_bucket_exists

    echo "Taking backup and uploading it to S3..."

    pg_dump_database | gzip | upload_to_bucket

    echo "Done."
}

main
