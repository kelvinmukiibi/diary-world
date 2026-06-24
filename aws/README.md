# AWS SAM backend

This folder contains the Version 2.0 proof-of-concept infrastructure and the
Lambda function that issues short-lived encrypted-upload URLs only after API
Gateway validates a Cognito ID token. S3 validates the signed content length and
SHA-256 checksum before accepting an encrypted object.

```powershell
sam validate --lint
sam build
sam deploy --guided
```

See [`../AWS_SETUP.md`](../AWS_SETUP.md) for account safety, deployment,
verification, configuration, CloudWatch, KMS, and cleanup instructions.
