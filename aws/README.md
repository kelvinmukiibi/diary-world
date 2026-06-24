# AWS SAM backend

This folder contains the Version 2.0 proof-of-concept infrastructure and the
Lambda function that issues short-lived encrypted-upload URLs.

```powershell
sam validate --lint
sam build
sam deploy --guided
```

See [`../AWS_SETUP.md`](../AWS_SETUP.md) for account safety, deployment,
verification, configuration, CloudWatch, KMS, and cleanup instructions.
