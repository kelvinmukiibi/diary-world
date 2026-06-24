# Version 2.0 Cybersecurity Notes

This document records the security goals, controls, threats, and known limits
of the AWS secure-backup proof of concept. Important implementation points are
also marked in source with `Version 2.0 cybersecurity change` comments.

## Security objectives and implemented controls

### 1. Confidentiality

- Selected diary recordings and identifying metadata are encrypted on-device
  with AES-256-GCM before any network request.
- PBKDF2-HMAC-SHA256 uses 210,000 iterations, a random salt, and a random nonce.
- The passphrase stays on the device and is neither persisted nor transmitted.
- All app, Cognito, API Gateway, and S3 traffic requires HTTPS. Android rejects
  cleartext HTTP through `network_security_config.xml`.
- S3 is private, blocks all public access, enforces TLS, disables ACL ownership,
  and applies AES-256 server-side encryption in addition to client encryption.

### 2. Integrity

- Flutter rejects empty, malformed, unsupported, or oversized encrypted
  envelopes and unsafe backup filenames before networking.
- Lambda accepts an exact JSON request structure and validates filename, file
  type, backup format, size, Cognito subject, and SHA-256 checksum encoding.
- The app computes SHA-256 over the final encrypted bytes. The checksum and
  exact content length are signed into the presigned S3 request.
- S3 verifies the checksum during `PutObject`; a mismatched or altered payload
  is rejected rather than reported as a successful backup.
- AES-GCM additionally authenticates the encrypted diary payload, so later
  decryption detects ciphertext modification.

### 3. Availability

- Cloud backup is optional and never runs automatically.
- Existing recording creation, storage, playback, retrieval, editing, and
  deletion paths do not depend on Cognito, API Gateway, Lambda, or S3.
- Network, authentication, checksum, timeout, or upload failures leave local
  diary data unchanged and provide accessible visual and spoken feedback.
- S3 versioning reduces accidental overwrite risk; retained resources reduce
  accidental stack-deletion risk.

### 4. Authentication and authorization

- Cognito authenticates the backup user. The password and one-hour ID token are
  held in memory only and are not written to SharedPreferences or files.
- API Gateway verifies the Cognito token signature and expiry before invoking
  Lambda. Lambda also requires a valid pseudonymous Cognito `sub` claim.
- Each user receives a separate `backups/{subject}/` S3 prefix.
- The Flutter app contains no AWS access key, secret key, session credential,
  API key, or Cognito client secret.
- Lambda uses a short-lived execution role limited to `s3:PutObject` under
  `backups/*`; it cannot list, read, or delete backups.
- Presigned URLs expire in 5–15 minutes and authorize one exact object upload
  with signed type, length, checksum, and encryption headers.

### 5. Data privacy

- Users select individual diary recordings and must confirm the upload.
- No automatic synchronization, background upload, or bulk default selection
  exists.
- The confirmation explains that local data remains on the device and that the
  backup passphrase is required for future decryption.
- The API receives only operational metadata. Diary titles, audio, dates, and
  passphrases are inside the client-encrypted envelope sent directly to S3.

### 6. Secure logging

- Lambda never logs the API event, body, Cognito subject, username, token,
  presigned URL, filename, checksum, diary content, or object data.
- Logs contain only request ID, validation outcome, encrypted byte count, and
  expiry duration.
- CloudWatch retention is 30 days. Operators must preserve this safe-event-only
  rule when adding alerts or dashboards.

### 7. Input validation

- Safe filenames must match
  `diary-world-backup-YYYYMMDDTHHMMSSZ.diarybackup.json`.
- Content type is restricted to `application/json`; backup format is restricted
  to `diary-world-v2`; size defaults to 1–25 MB.
- The encrypted envelope must identify Version 2, AES-256-GCM, and
  PBKDF2-HMAC-SHA256 and contain non-empty valid Base64 ciphertext.
- API Gateway validates the request model, and Lambda independently repeats
  security-sensitive validation before signing an upload.
- Unknown fields are rejected to keep the request contract auditable.

### 8. Key and secret management

- `.gitignore` excludes `.env*` except `.env.example`, local configuration,
  keystores, certificates, credentials, logs, SAM output, and state files.
- `.env.example` and `config/aws_backup.example.json` contain placeholders only.
- The API endpoint, AWS region, and no-secret Cognito mobile client ID are safe
  configuration values. Passwords, tokens, diary passphrases, and AWS
  credentials must never be placed in either example or a build command.
- Deployment should use IAM Identity Center/SSO and short-lived credentials, not
  root or long-lived IAM user keys.

### 9. Network security

- The app accepts only an `https` API endpoint and only an HTTPS S3 upload URL.
- Android `usesCleartextTraffic="false"` and the network security configuration
  reject cleartext traffic.
- The S3 bucket policy denies requests that do not use TLS and denies uploads
  missing the required AES-256 server-side encryption header.

### 10. Auditability

- Security changes are isolated to `release-2.0-aws-secure-backup` and documented
  here, in `CHANGELOG.md`, `README_VERSION_2_AWS.md`, and `AWS_SETUP.md`.
- Important code paths carry `Version 2.0 cybersecurity change` comments.
- CloudWatch provides safe operational events without exposing diary data.
- Release 1.0, tag `v1.0`, its APK, and its history remain unchanged.

## Short threat model

| Threat | Main control | Residual risk |
| --- | --- | --- |
| Leaked AWS credentials | No AWS credentials in Flutter; deployment uses SSO; Lambda uses a scoped role | A compromised administrator or CI environment can still expose deployment credentials |
| Public S3 exposure | Block Public Access, private ownership, TLS-only bucket policy, IaC review | A future unauthorized infrastructure change could weaken policy |
| Unauthorized uploads | Cognito authorizer, Lambda claim validation, per-user prefixes, short URL expiry | Compromised user credentials or token theft permit uploads until revocation/expiry |
| Presigned URL replay | One object key, signed checksum/length/headers, 5–15 minute expiry | The same exact object may be overwritten during the short validity window |
| Modified or truncated upload | SHA-256 and content length validated by S3; AES-GCM authenticates ciphertext | Bugs in future restore code could mishandle authenticated-decryption failures |
| Excessive or sensitive logging | Explicit safe-field logging and 30-day retention | Future developers may accidentally add request or identity logging |
| Accidental sensitive upload | Entry selection, confirmation, local encryption, no automatic sync | A user can still intentionally select the wrong entry |
| Denial of service or cost abuse | Authentication and size limits | Proof of concept lacks production-grade quotas, WAF rules, and alarms |
| Lost passphrase | Clear warning; key is never uploaded | There is no recovery mechanism, so encrypted data becomes unrecoverable |

## Proof-of-concept limitations

This is a secure-backup proof of concept, not a complete production security
implementation. Production deployment still requires:

- stronger account recovery, MFA-capable authentication UX, token refresh and
  revocation handling, and secure platform keystore integration;
- API Gateway throttling, per-user quotas, AWS WAF where appropriate, anomaly
  detection, CloudWatch alarms, cost controls, and incident response;
- penetration testing, mobile application security testing, dependency and IaC
  scanning, code review, and a formal privacy/security threat assessment;
- defined backup retention, deletion, restore, disaster-recovery, and key
  rotation processes;
- customer-managed KMS keys where policy requires separate key control;
- a streaming encryption/upload design for large recordings rather than holding
  the complete encrypted backup in memory;
- restricted production CORS origins, regional data-residency decisions,
  consent and privacy notices, and legal/compliance review;
- a restore/decryption interface that treats every authentication or integrity
  failure as fatal and never exposes partial plaintext.

## Secret incident rule

If a secret is committed, deleting the file is not enough. Revoke or rotate the
credential immediately, audit its use, and remove it from Version 2.0 history
through an approved incident-response process. Do not rewrite Release 1.0.
