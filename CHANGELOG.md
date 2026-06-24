# Changelog

## 2.0.0 - AWS secure-backup proof of concept

- Added an optional Settings screen for selecting local diary recordings.
- Added explicit confirmation and accessible spoken/visual backup feedback.
- Added client-side AES-256-GCM encryption with passphrase-based key derivation.
- Added connectivity handling and HTTPS-only endpoint configuration.
- Added a SAM backend for API Gateway, Lambda, private encrypted S3 storage,
  least-privilege IAM, short-lived presigned URLs, and CloudWatch logging.
- Added AWS deployment, security, migration, and local build documentation.
- Expanded secret and generated-output exclusions.
- Disabled Android cleartext HTTP traffic.

### Migration note

Version 2.0 is developed only on `release-2.0-aws-secure-backup`. The
`Release1.0` branch, `v1.0` tag, Release 1.0 APK, and Git history were not
modified, renamed, rebased, overwritten, or force-pushed.
