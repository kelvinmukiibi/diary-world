import 'package:flutter_test/flutter_test.dart';
import 'package:diaryworld/aws_backup/diary_backup_entry.dart';

void main() {
  test('legacy recording metadata remains compatible with Version 2.0', () {
    const legacy = 'Morning|24 June 2026|1:00 PM|C:\\audio\\morning.aac';
    final entry = DiaryBackupEntry.fromLegacyRecord(legacy);

    expect(entry, isNotNull);
    expect(entry!.name, 'Morning');
    expect(entry.filePath, r'C:\audio\morning.aac');
  });
}
