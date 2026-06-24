# Security Notes

## Implemented controls

- No AWS access keys, secret keys, session tokens, or permanent cloud
  credentials exist in the Flutter application.
- Selected diary recordings and their metadata are encrypted on-device with
  AES-256-GCM before networking begins.
- PBKDF2-HMAC-SHA256 uses 210,000 iterations and a random per-backup salt. Each
  encryption also uses a random nonce.
- The passphrase is not stored or transmitted. The backup cannot be recovered
  if the user loses it.
- Upload is explicit, selected-entry only, and guarded by a confirmation dialog.
- The local diary is not changed on upload success or failure.
- The API accepts a fixed content type/format and enforces a 25 MB default size
  limit in Flutter and Lambda. The declared content length is signed into the
  S3 request so the uploaded byte count must match.
- Presigned URLs expire after 5–15 minutes and authorize one S3 `PutObject`.
- The S3 bucket blocks public access, enforces TLS, uses bucket-owner ownership,
  versioning, and AES-256 default encryption.
- The Lambda role can put only `backups/*` objects. It cannot read or delete.
- Android blocks cleartext HTTP traffic.
- CloudWatch logs omit diary content, request bodies, passphrases, presigned
  URLs, and object data.
- `.gitignore` excludes local config, environment files, signing material,
  credentials, logs, and generated infrastructure state.

## Proof-of-concept limitations and production work

- The presign endpoint has request validation but no end-user authentication or
  authorization. Before production, add Amazon Cognito/OIDC authorization,
  per-user S3 prefixes, quotas, throttling, abuse monitoring, and ownership
  checks. An API key alone is not user authentication.
- No restore/decryption user interface is included yet.
- The app currently encrypts whole selected recordings in memory. Large backups
  should use audited streaming encryption and multipart upload in production.
- A passphrase can be weak even at 12 characters. Production UX should use a
  password-strength meter, recovery-key workflow, and secure key storage after
  a formal threat-model review.
- Dependency versions and cryptographic choices require routine security review.
- SSE-S3 protects data at rest on AWS after upload. Use a customer-managed KMS
  key if policy requires separate key control or audit boundaries.
- The API has no malware/content scanning because it receives only metadata and
  S3 receives an opaque encrypted object. Add object quarantine and lifecycle
  policies if the threat model requires them.
- CORS is permissive for proof-of-concept Flutter web compatibility. Restrict
  allowed origins if a web client is deployed.
- Privacy notices, consent language, retention/deletion workflows, regional
  data residency, and legal compliance remain product-owner responsibilities.

## Secret-handling rule

If a secret is ever committed, deleting the file is not enough. Revoke/rotate
the credential immediately, audit its use, and remove it from Git history using
an approved incident-response process. Do not rewrite Release 1.0 history.
