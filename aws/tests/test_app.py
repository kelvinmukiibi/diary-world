import json
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, patch


os.environ.setdefault("BACKUP_BUCKET", "unit-test-bucket")
os.environ.setdefault("MAX_UPLOAD_BYTES", "26214400")
os.environ.setdefault("URL_EXPIRY_SECONDS", "600")

# Keep unit tests local and credential-free. AWS Lambda supplies boto3 at
# runtime; these module stubs prevent a developer test from contacting AWS.
boto3_stub = types.ModuleType("boto3")
boto3_stub.client = MagicMock(return_value=MagicMock())
botocore_stub = types.ModuleType("botocore")
botocore_config_stub = types.ModuleType("botocore.config")
botocore_config_stub.Config = MagicMock
sys.modules.setdefault("boto3", boto3_stub)
sys.modules.setdefault("botocore", botocore_stub)
sys.modules.setdefault("botocore.config", botocore_config_stub)

from aws.functions.presign_upload import app  # noqa: E402


class Context:
    aws_request_id = "safe-test-request-id"


class PresignUploadTests(unittest.TestCase):
    def test_rejects_oversized_backup(self):
        event = {
            "body": json.dumps(
                {
                    "contentType": "application/json",
                    "sizeBytes": 26214401,
                    "backupFormat": "diary-world-v2",
                }
            )
        }

        response = app.lambda_handler(event, Context())

        self.assertEqual(response["statusCode"], 400)
        self.assertNotIn("uploadUrl", response["body"])

    @patch.object(app.S3, "generate_presigned_url")
    def test_returns_short_lived_encrypted_put_url(self, generate_url):
        generate_url.return_value = "https://s3.example/upload"
        event = {
            "body": json.dumps(
                {
                    "contentType": "application/json",
                    "sizeBytes": 1024,
                    "backupFormat": "diary-world-v2",
                }
            )
        }

        response = app.lambda_handler(event, Context())
        body = json.loads(response["body"])

        self.assertEqual(response["statusCode"], 200)
        self.assertEqual(body["expiresIn"], 600)
        self.assertEqual(
            body["requiredHeaders"]["x-amz-server-side-encryption"],
            "AES256",
        )
        self.assertEqual(body["requiredHeaders"]["Content-Length"], "1024")
        call = generate_url.call_args.kwargs
        self.assertEqual(call["ExpiresIn"], 600)
        self.assertEqual(call["Params"]["ServerSideEncryption"], "AES256")
        self.assertEqual(call["Params"]["ContentLength"], 1024)


if __name__ == "__main__":
    unittest.main()
