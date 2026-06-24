# Diary World Version 2.0: AWS Secure Backup

Version 2.0 adds an optional proof-of-concept backup path for selected local
diary recordings. Release 1.0 remains unchanged on the `Release1.0` branch and
at tag `v1.0`; Version 2.0 work lives only on
`release-2.0-aws-secure-backup`.

## What changed

- A **Secure Cloud Backup** entry is available in Settings.
- Users explicitly select recordings and confirm every upload.
- Selected audio and metadata are encrypted locally with AES-256-GCM.
- A user passphrase derives the encryption key with PBKDF2-HMAC-SHA256. The
  passphrase is not uploaded or stored by the app.
- The app requests a 5–15 minute S3 presigned URL through API Gateway and
  Lambda. No permanent AWS credential is present in Flutter.
- The S3 bucket is private, blocks public access, requires TLS, uses AES-256
  server-side encryption, and retains object versions.
- Network failures leave all local recordings unchanged and produce visual and
  spoken feedback.
- Android cleartext HTTP traffic is disabled.

## Local-first behavior

Backup is disabled until an HTTPS API endpoint is supplied at build time. It is
never automatic. Recording, playback, and other Release 1.0 features continue
to use local storage and work without internet access.

## Configure and run

Copy `config/aws_backup.example.json` to the ignored file
`config/aws_backup.json`, replace the placeholder with the deployed endpoint,
then run:

```powershell
flutter pub get
flutter run --dart-define-from-file=config/aws_backup.json
```

Or pass the value without creating a file:

```powershell
flutter run --dart-define=AWS_BACKUP_API_ENDPOINT=https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/v2/backup/presign
```

Never place AWS access keys, tokens, passphrases, or personal diary data in the
configuration file. The endpoint is not a secret; the local file is ignored to
prevent environment-specific values from being committed accidentally.

## Build a Version 2.0 debug APK

```powershell
flutter pub get
flutter analyze
flutter build apk --debug --dart-define-from-file=config/aws_backup.json
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Important recovery note

This proof of concept uploads encrypted backup objects but does not yet include
a restore screen. Keep the passphrase in a trusted password manager. Losing it
means the client-encrypted backup cannot be decrypted.

See [AWS_SETUP.md](AWS_SETUP.md) for deployment and
[SECURITY_NOTES.md](SECURITY_NOTES.md) for security boundaries.
