"""Generate short-lived S3 upload URLs without receiving diary content."""

import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.config import Config


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

S3 = boto3.client(
    "s3",
    config=Config(signature_version="s3v4", retries={"max_attempts": 2}),
)
BUCKET = os.environ["BACKUP_BUCKET"]
MAX_UPLOAD_BYTES = int(os.environ.get("MAX_UPLOAD_BYTES", "26214400"))
URL_EXPIRY_SECONDS = min(
    max(int(os.environ.get("URL_EXPIRY_SECONDS", "600")), 300),
    900,
)
ALLOWED_CONTENT_TYPES = {"application/json"}
ALLOWED_BACKUP_FORMATS = {"diary-world-v2"}


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(body),
    }


def lambda_handler(event, context):
    """Validate metadata and create one narrowly scoped presigned PUT URL."""
    # Version 2.0 AWS secure-backup change: never log event/body because it may
    # contain user-controlled data. Logs contain only safe operational fields.
    request_id = getattr(context, "aws_request_id", "unknown")

    try:
        body = json.loads(event.get("body") or "{}")
    except (TypeError, json.JSONDecodeError):
        LOGGER.warning("invalid_json request_id=%s", request_id)
        return _response(400, {"message": "Invalid JSON request."})

    if not isinstance(body, dict) or set(body) != {
        "contentType",
        "sizeBytes",
        "backupFormat",
    }:
        LOGGER.warning("invalid_fields request_id=%s", request_id)
        return _response(400, {"message": "Invalid request fields."})

    content_type = body.get("contentType")
    backup_format = body.get("backupFormat")
    size_bytes = body.get("sizeBytes")
    if (
        content_type not in ALLOWED_CONTENT_TYPES
        or backup_format not in ALLOWED_BACKUP_FORMATS
        or isinstance(size_bytes, bool)
        or not isinstance(size_bytes, int)
        or size_bytes < 1
        or size_bytes > MAX_UPLOAD_BYTES
    ):
        LOGGER.warning("validation_failed request_id=%s", request_id)
        return _response(400, {"message": "Backup metadata was rejected."})

    date_prefix = datetime.now(timezone.utc).strftime("%Y/%m/%d")
    object_key = f"backups/{date_prefix}/{uuid.uuid4()}.diarybackup.json"
    required_headers = {
        "Content-Type": content_type,
        "Content-Length": str(size_bytes),
        "x-amz-server-side-encryption": "AES256",
    }

    upload_url = S3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": BUCKET,
            "Key": object_key,
            "ContentType": content_type,
            "ContentLength": size_bytes,
            "ServerSideEncryption": "AES256",
        },
        ExpiresIn=URL_EXPIRY_SECONDS,
        HttpMethod="PUT",
    )

    LOGGER.info(
        "presign_issued request_id=%s size_bytes=%d expires_seconds=%d",
        request_id,
        size_bytes,
        URL_EXPIRY_SECONDS,
    )
    return _response(
        200,
        {
            "uploadUrl": upload_url,
            "objectKey": object_key,
            "expiresIn": URL_EXPIRY_SECONDS,
            "requiredHeaders": required_headers,
        },
    )
