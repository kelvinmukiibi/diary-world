import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'diary_backup_entry.dart';

class BackupEncryptionException implements Exception {
  const BackupEncryptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupEncryptionService {
  BackupEncryptionService({Random? secureRandom})
      : _secureRandom = secureRandom ?? Random.secure();

  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _pbkdf2Iterations = 210000;

  final Random _secureRandom;

  // Version 2.0 AWS secure-backup change: diary audio and its identifying
  // metadata are encrypted together before any presigned URL is requested.
  // The passphrase never leaves the device and is not included in the envelope.
  Future<Uint8List> encryptEntries({
    required List<DiaryBackupEntry> entries,
    required String passphrase,
  }) async {
    if (entries.isEmpty) {
      throw const BackupEncryptionException('Select at least one diary entry.');
    }
    if (passphrase.length < 12) {
      throw const BackupEncryptionException(
        'Use a backup passphrase with at least 12 characters.',
      );
    }

    final encryptedItems = <Map<String, Object>>[];
    for (final entry in entries) {
      final file = File(entry.filePath);
      if (!await file.exists()) {
        throw BackupEncryptionException(
          'The local recording "${entry.name}" could not be found.',
        );
      }

      final audioBytes = await file.readAsBytes();
      encryptedItems.add({
        'name': entry.name,
        'date': entry.date,
        'time': entry.time,
        'audioBase64': base64Encode(audioBytes),
      });
    }

    final plaintext = utf8.encode(jsonEncode({
      'format': 'diary-world-v2',
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'entries': encryptedItems,
    }));

    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final keyDerivation = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    final secretKey = await keyDerivation.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final secretBox = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = {
      'format': 'diary-world-encrypted-backup',
      'version': 2,
      'encryption': 'AES-256-GCM',
      'keyDerivation': 'PBKDF2-HMAC-SHA256',
      'iterations': _pbkdf2Iterations,
      'saltBase64': base64Encode(salt),
      'nonceBase64': base64Encode(secretBox.nonce),
      'macBase64': base64Encode(secretBox.mac.bytes),
      'ciphertextBase64': base64Encode(secretBox.cipherText),
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _secureRandom.nextInt(256));
}
