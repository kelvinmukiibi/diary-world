import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AwsBackupException implements Exception {
  const AwsBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AwsBackupResult {
  const AwsBackupResult({required this.backupId});

  final String backupId;
}

class AwsBackupService {
  AwsBackupService({
    String? endpoint,
    http.Client? client,
    Connectivity? connectivity,
  })  : _endpointValue =
            endpoint ?? const String.fromEnvironment('AWS_BACKUP_API_ENDPOINT'),
        _client = client ?? http.Client(),
        _connectivity = connectivity ?? Connectivity();

  static const int maxBackupBytes = 25 * 1024 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _uploadTimeout = Duration(minutes: 2);

  final String _endpointValue;
  final http.Client _client;
  final Connectivity _connectivity;

  static final RegExp _fileNamePattern = RegExp(
    r'^diary-world-backup-[0-9]{8}T[0-9]{6}Z\.diarybackup\.json$',
  );
  static final RegExp _backupIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  Uri? get configuredEndpoint {
    final uri = Uri.tryParse(_endpointValue);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  // Version 2.0 cybersecurity change: require an authenticated API request,
  // validate the encrypted envelope, and bind its SHA-256 checksum, length,
  // safe filename, content type, and encryption header into the S3 signature.
  Future<AwsBackupResult> uploadEncryptedBackup({
    required Uint8List encryptedBytes,
    required String idToken,
    required String fileName,
  }) async {
    final endpoint = configuredEndpoint;
    if (endpoint == null) {
      throw const AwsBackupException(
        'Cloud backup is not configured. Add the HTTPS API endpoint at build time.',
      );
    }
    if (encryptedBytes.isEmpty || encryptedBytes.length > maxBackupBytes) {
      throw const AwsBackupException(
        'The encrypted backup must be between 1 byte and 25 MB.',
      );
    }
    if (!_fileNamePattern.hasMatch(fileName)) {
      throw const AwsBackupException('The backup filename is invalid.');
    }
    if (idToken.isEmpty ||
        idToken.length > 8192 ||
        idToken.split('.').length != 3) {
      throw const AwsBackupException('A valid backup sign-in is required.');
    }
    _validateEncryptedEnvelope(encryptedBytes);

    final checksumSha256 = base64Encode(sha256.convert(encryptedBytes).bytes);

    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw const AwsBackupException(
        'No network connection. Your diary remains saved locally; try again later.',
      );
    }

    try {
      final presignResponse = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              // REST API Cognito authorizers expect the raw JWT in the
              // configured Authorization identity-source header.
              'Authorization': idToken,
            },
            body: jsonEncode({
              'fileName': fileName,
              'contentType': 'application/json',
              'sizeBytes': encryptedBytes.length,
              'backupFormat': 'diary-world-v2',
              'checksumSha256': checksumSha256,
            }),
          )
          .timeout(_requestTimeout);

      if (presignResponse.statusCode != 200) {
        throw const AwsBackupException(
          'The backup service could not prepare a secure upload. Try again later.',
        );
      }

      final payload = jsonDecode(presignResponse.body);
      if (payload is! Map<String, dynamic>) {
        throw const AwsBackupException(
            'The backup service returned invalid data.');
      }
      final uploadUrl = Uri.tryParse(payload['uploadUrl'] as String? ?? '');
      final backupId = payload['backupId'] as String?;
      final responseHeaders = payload['requiredHeaders'];
      final uploadHost = uploadUrl?.host.toLowerCase() ?? '';
      final isAwsS3Host = (uploadHost.endsWith('.amazonaws.com') ||
              uploadHost.endsWith('.amazonaws.com.cn')) &&
          (uploadHost.startsWith('s3.') ||
              uploadHost.contains('.s3.') ||
              uploadHost.contains('.s3-'));
      if (uploadUrl == null ||
          uploadUrl.scheme != 'https' ||
          !isAwsS3Host ||
          backupId == null ||
          !_backupIdPattern.hasMatch(backupId) ||
          responseHeaders is! Map<String, dynamic> ||
          responseHeaders['x-amz-checksum-sha256'] != checksumSha256) {
        throw const AwsBackupException(
            'The backup service returned invalid data.');
      }

      final uploadHeaders = responseHeaders.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      final uploadResponse = await _client
          .put(uploadUrl, headers: uploadHeaders, body: encryptedBytes)
          .timeout(_uploadTimeout);
      if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
        throw const AwsBackupException(
          'The encrypted upload failed. Your local diary was not changed.',
        );
      }
      final confirmedChecksum = uploadResponse.headers['x-amz-checksum-sha256'];
      if (confirmedChecksum != null && confirmedChecksum != checksumSha256) {
        throw const AwsBackupException(
          'The uploaded backup failed its integrity check.',
        );
      }

      return AwsBackupResult(backupId: backupId);
    } on TimeoutException {
      throw const AwsBackupException(
        'The network request timed out. Your local diary was not changed.',
      );
    } on AwsBackupException {
      rethrow;
    } catch (_) {
      // Do not include raw server responses, URLs, or diary content in errors.
      throw const AwsBackupException(
        'Cloud backup is unavailable. Check your connection and try again.',
      );
    }
  }

  void _validateEncryptedEnvelope(Uint8List encryptedBytes) {
    try {
      final envelope = jsonDecode(utf8.decode(encryptedBytes));
      if (envelope is! Map<String, dynamic> ||
          envelope['format'] != 'diary-world-encrypted-backup' ||
          envelope['version'] != 2 ||
          envelope['encryption'] != 'AES-256-GCM' ||
          envelope['keyDerivation'] != 'PBKDF2-HMAC-SHA256' ||
          envelope['ciphertextBase64'] is! String ||
          (envelope['ciphertextBase64'] as String).isEmpty) {
        throw const FormatException();
      }
      if (base64Decode(envelope['ciphertextBase64'] as String).isEmpty) {
        throw const FormatException();
      }
    } catch (_) {
      throw const AwsBackupException(
        'The encrypted backup is empty or malformed.',
      );
    }
  }

  void close() => _client.close();
}
