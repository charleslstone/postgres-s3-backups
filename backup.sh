#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

log() {
    echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] $*"
}

s3() {
    aws s3 --region "$AWS_REGION" "$@"
}

check_bucket_access() {
    log "Checking access to S3 bucket '$S3_BUCKET_NAME' in region '$AWS_REGION'..."

    if aws s3api head-bucket \
        --bucket "$S3_BUCKET_NAME" \
        --region "$AWS_REGION"
    then
        log "S3 bucket exists and is accessible."
    else
        log "ERROR: Unable to access S3 bucket '$S3_BUCKET_NAME'."
        log "Check S3_BUCKET_NAME, AWS_REGION, AWS credentials, and IAM permissions."
        return 1
    fi
}

pg_dump_database() {
    log "Starting PostgreSQL pg_dump..."

    if pg_dump \
        --no-owner \
        --no-privileges \
        --clean \
        --if-exists \
        --quote-all-identifiers \
        "$DATABASE_URL"
    then
        log "PostgreSQL pg_dump completed successfully."
    else
        log "ERROR: PostgreSQL pg_dump failed."
        return 1
    fi
}

upload_to_bucket() {
    backup_name="pralana-postgres-$(date -u +%Y-%m-%dT%H-%M-%SZ).sql.gz"

    log "Uploading compressed backup to:"
    log "s3://$S3_BUCKET_NAME/$backup_name"

    if s3 cp - "s3://$S3_BUCKET_NAME/$backup_name"
    then
        log "S3 upload completed successfully."
    else
        log "ERROR: S3 upload failed."
        return 1
    fi
}

main() {
    log "Pralana PostgreSQL backup started."

    check_bucket_access

    log "Starting database dump, gzip compression, and S3 upload..."

    if pg_dump_database | gzip | upload_to_bucket
    then
        log "Backup pipeline completed successfully."
    else
        log "ERROR: Backup pipeline failed."
        return 1
    fi

    log "Pralana PostgreSQL backup finished successfully."
}

main
