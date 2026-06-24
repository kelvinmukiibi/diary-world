import 'dart:convert';
import 'dart:typed_data';

import 'package:diaryworld/aws_backup/aws_backup_service.dart';
import 'package:diaryworld/aws_backup/cognito_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validToken = 'header.payload.signature';
  const validFileName = 'diary-world-backup-20260624T130000Z.diarybackup.json';

  test('rejects malformed encrypted envelopes before networking', () async {
    final service =
        AwsBackupService(endpoint: 'https://api.example.com/presign');
    addTearDown(service.close);

    expect(
      () => service.uploadEncryptedBackup(
        encryptedBytes: Uint8List.fromList(utf8.encode('{}')),
        idToken: validToken,
        fileName: validFileName,
      ),
      throwsA(isA<AwsBackupException>()),
    );
  });

  test('rejects unsafe filenames before networking', () async {
    final service =
        AwsBackupService(endpoint: 'https://api.example.com/presign');
    addTearDown(service.close);

    expect(
      () => service.uploadEncryptedBackup(
        encryptedBytes: Uint8List.fromList([1]),
        idToken: validToken,
        fileName: '../../diary.aac',
      ),
      throwsA(isA<AwsBackupException>()),
    );
  });

  test('Cognito configuration accepts only safe region and client ID shapes',
      () {
    final configured = CognitoAuthService(
      region: 'us-east-1',
      clientId: '1234567890abcdefghij',
    );
    final rejected = CognitoAuthService(
      region: 'http://example.com',
      clientId: 'short',
    );
    addTearDown(configured.close);
    addTearDown(rejected.close);

    expect(configured.isConfigured, isTrue);
    expect(rejected.isConfigured, isFalse);
  });
}
