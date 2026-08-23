"""Generate short-lived S3 upload URLs without receiving diary content."""

import json
import logging
import os
import base64
import re
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
FILE_NAME_PATTERN = re.compile(
    r"^diary-world-backup-[0-9]{8}T[0-9]{6}Z\.diarybackup\.json$"
)
SUBJECT_PATTERN = re.compile(r"^[0-9a-fA-F-]{36}$")


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
    # Version 2.0 cybersecurity change: never log event/body because it may
    # contain user-controlled data. Logs contain only safe operational fields.
    request_id = getattr(context, "aws_request_id", "unknown")

    # API Gateway verifies the Cognito JWT signature and expiry. Lambda also
    # requires a valid pseudonymous subject before issuing an upload URL.
    claims = (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("claims", {})
        if isinstance(event, dict)
        else {}
    )
    subject = claims.get("sub") if isinstance(claims, dict) else None
    if not isinstance(subject, str) or not SUBJECT_PATTERN.fullmatch(subject):
        LOGGER.warning("authorization_context_missing request_id=%s", request_id)
        return _response(401, {"message": "Authentication is required."})

    try:
        body = json.loads(event.get("body") or "{}")
    except (TypeError, json.JSONDecodeError):
        LOGGER.warning("invalid_json request_id=%s", request_id)
        return _response(400, {"message": "Invalid JSON request."})

    if not isinstance(body, dict) or set(body) != {
        "contentType",
        "sizeBytes",
        "backupFormat",
        "fileName",
        "checksumSha256",
    }:
        LOGGER.warning("invalid_fields request_id=%s", request_id)
        return _response(400, {"message": "Invalid request fields."})

    content_type = body.get("contentType")
    backup_format = body.get("backupFormat")
    size_bytes = body.get("sizeBytes")
    file_name = body.get("fileName")
    checksum_sha256 = body.get("checksumSha256")
    try:
        checksum_bytes = base64.b64decode(checksum_sha256, validate=True)
    except (TypeError, ValueError):
        checksum_bytes = b""
    if (
        content_type not in ALLOWED_CONTENT_TYPES
        or backup_format not in ALLOWED_BACKUP_FORMATS
        or isinstance(size_bytes, bool)
        or not isinstance(size_bytes, int)
        or size_bytes < 1
        or size_bytes > MAX_UPLOAD_BYTES
        or not isinstance(file_name, str)
        or not FILE_NAME_PATTERN.fullmatch(file_name)
        or len(checksum_bytes) != 32
    ):
        LOGGER.warning("validation_failed request_id=%s", request_id)
        return _response(400, {"message": "Backup metadata was rejected."})

    date_prefix = datetime.now(timezone.utc).strftime("%Y/%m/%d")
    backup_id = uuid.uuid4()
    object_key = (
        f"backups/{subject}/{date_prefix}/{backup_id}.diarybackup.json"
    )
    required_headers = {
        "Content-Type": content_type,
        # Version 2.0 cybersecurity change: validate upload size before
        # presigning, but do not sign Content-Length. Mobile HTTP clients may
        # manage that header themselves, and S3 rejects presigned PUTs if a
        # signed Content-Length is not reproduced exactly.
        "x-amz-checksum-sha256": checksum_sha256,
        "x-amz-server-side-encryption": "AES256",
    }

    upload_url = S3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": BUCKET,
            "Key": object_key,
            "ContentType": content_type,
            "ChecksumSHA256": checksum_sha256,
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
            "backupId": str(backup_id),
            "expiresIn": URL_EXPIRY_SECONDS,
            "requiredHeaders": required_headers,
        },
    )
