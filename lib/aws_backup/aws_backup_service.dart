import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class AwsBackupException implements Exception {
  const AwsBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AwsBackupResult {
  const AwsBackupResult({required this.objectKey});

  final String objectKey;
}

class AwsBackupService {
  AwsBackupService({
    String? endpoint,
    http.Client? client,
    Connectivity? connectivity,
  })  : _endpointValue = endpoint ??
            const String.fromEnvironment('AWS_BACKUP_API_ENDPOINT'),
        _client = client ?? http.Client(),
        _connectivity = connectivity ?? Connectivity();

  static const int maxBackupBytes = 25 * 1024 * 1024;
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration _uploadTimeout = Duration(minutes: 2);

  final String _endpointValue;
  final http.Client _client;
  final Connectivity _connectivity;

  Uri? get configuredEndpoint {
    final uri = Uri.tryParse(_endpointValue);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  // Version 2.0 AWS secure-backup change: the app asks the backend for a
  // short-lived URL, then uploads encrypted bytes without AWS credentials.
  Future<AwsBackupResult> uploadEncryptedBackup(Uint8List encryptedBytes) async {
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
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contentType': 'application/json',
              'sizeBytes': encryptedBytes.length,
              'backupFormat': 'diary-world-v2',
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
        throw const AwsBackupException('The backup service returned invalid data.');
      }
      final uploadUrl = Uri.tryParse(payload['uploadUrl'] as String? ?? '');
      final objectKey = payload['objectKey'] as String?;
      final responseHeaders = payload['requiredHeaders'];
      if (uploadUrl == null ||
          uploadUrl.scheme != 'https' ||
          objectKey == null ||
          responseHeaders is! Map<String, dynamic>) {
        throw const AwsBackupException('The backup service returned invalid data.');
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

      return AwsBackupResult(objectKey: objectKey);
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

  void close() => _client.close();
}
