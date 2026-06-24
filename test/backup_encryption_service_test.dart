import 'dart:convert';
import 'dart:io';

import 'package:diaryworld/aws_backup/backup_encryption_service.dart';
import 'package:diaryworld/aws_backup/diary_backup_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encrypted backup envelope does not expose diary content', () async {
    final directory = await Directory.systemTemp.createTemp('diary-backup-test');
    addTearDown(() => directory.delete(recursive: true));
    final audio = File('${directory.path}/entry.aac');
    await audio.writeAsBytes(utf8.encode('private diary audio content'));

    final bytes = await BackupEncryptionService().encryptEntries(
      entries: [
        DiaryBackupEntry(
          name: 'Private entry title',
          date: '24 June 2026',
          time: '1:00 PM',
          filePath: audio.path,
        ),
      ],
      passphrase: 'a-strong-test-passphrase',
    );

    final encodedEnvelope = utf8.decode(bytes);
    final envelope = jsonDecode(encodedEnvelope) as Map<String, dynamic>;
    expect(envelope['encryption'], 'AES-256-GCM');
    expect(envelope['iterations'], 210000);
    expect(encodedEnvelope, isNot(contains('Private entry title')));
    expect(encodedEnvelope, isNot(contains('private diary audio content')));
  });

  test('passphrases shorter than 12 characters are rejected', () async {
    expect(
      () => BackupEncryptionService().encryptEntries(
        entries: const [
          DiaryBackupEntry(
            name: 'Entry',
            date: 'Date',
            time: 'Time',
            filePath: 'unused',
          ),
        ],
        passphrase: 'short',
      ),
      throwsA(isA<BackupEncryptionException>()),
    );
  });
}
