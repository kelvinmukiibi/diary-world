// Version 2.0 cybersecurity change: a small model isolates the legacy
// SharedPreferences recording format from the new backup feature.
class DiaryBackupEntry {
  const DiaryBackupEntry({
    required this.name,
    required this.date,
    required this.time,
    required this.filePath,
  });

  final String name;
  final String date;
  final String time;
  final String filePath;

  static DiaryBackupEntry? fromLegacyRecord(String value) {
    final parts = value.split('|');
    if (parts.length < 4 || parts.take(4).any((part) => part.trim().isEmpty)) {
      return null;
    }

    return DiaryBackupEntry(
      name: parts[0],
      date: parts[1],
      time: parts[2],
      filePath: parts.sublist(3).join('|'),
    );
  }
}
