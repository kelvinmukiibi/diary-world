import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CognitoAuthException implements Exception {
  const CognitoAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CognitoAuthService {
  CognitoAuthService({
    String? region,
    String? clientId,
    http.Client? client,
  })  : _region = region ?? const String.fromEnvironment('AWS_COGNITO_REGION'),
        _clientId =
            clientId ?? const String.fromEnvironment('AWS_COGNITO_CLIENT_ID'),
        _client = client ?? http.Client();

  static const Duration _timeout = Duration(seconds: 20);
  static final RegExp _regionPattern = RegExp(r'^[a-z]{2}(?:-[a-z]+)+-\d$');
  static final RegExp _clientIdPattern = RegExp(r'^[A-Za-z0-9]{20,128}$');

  final String _region;
  final String _clientId;
  final http.Client _client;

  bool get isConfigured =>
      _regionPattern.hasMatch(_region) && _clientIdPattern.hasMatch(_clientId);

  // Version 2.0 cybersecurity change: authenticate directly with the deployed
  // Cognito user pool. The password and short-lived ID token remain in memory;
  // neither is written to SharedPreferences, logs, source code, or backups.
  Future<String> authenticate({
    required String username,
    required String password,
  }) async {
    if (!isConfigured) {
      throw const CognitoAuthException(
        'Cloud authentication is not configured for this build.',
      );
    }
    if (username.trim().isEmpty || username.length > 128 || password.isEmpty) {
      throw const CognitoAuthException(
        'Enter a valid backup username and password.',
      );
    }

    final endpoint = Uri.https('cognito-idp.$_region.amazonaws.com', '/');
    try {
      final response = await _client
          .post(
            endpoint,
            headers: const {
              'Content-Type': 'application/x-amz-json-1.1',
              'X-Amz-Target': 'AWSCognitoIdentityProviderService.InitiateAuth',
            },
            body: jsonEncode({
              'AuthFlow': 'USER_PASSWORD_AUTH',
              'ClientId': _clientId,
              'AuthParameters': {
                'USERNAME': username.trim(),
                'PASSWORD': password,
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw const CognitoAuthException(
          'Authentication failed. Check your backup account and try again.',
        );
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> || body['ChallengeName'] != null) {
        throw const CognitoAuthException(
          'This account requires an authentication step not supported by the proof of concept.',
        );
      }
      final authenticationResult = body['AuthenticationResult'];
      final idToken = authenticationResult is Map<String, dynamic>
          ? authenticationResult['IdToken'] as String?
          : null;
      if (idToken == null ||
          idToken.length > 8192 ||
          idToken.split('.').length != 3) {
        throw const CognitoAuthException(
          'Authentication did not return a valid short-lived token.',
        );
      }

      return idToken;
    } on TimeoutException {
      throw const CognitoAuthException(
        'Authentication timed out. Your local diary was not changed.',
      );
    } on CognitoAuthException {
      rethrow;
    } catch (_) {
      // Never expose Cognito responses, usernames, passwords, or tokens.
      throw const CognitoAuthException(
        'Cloud authentication is unavailable. Try again later.',
      );
    }
  }

  void close() => _client.close();
}
