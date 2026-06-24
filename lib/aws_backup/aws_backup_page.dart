import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'aws_backup_service.dart';
import 'backup_encryption_service.dart';
import 'cognito_auth_service.dart';
import 'diary_backup_entry.dart';

class AwsBackupPage extends StatefulWidget {
  const AwsBackupPage({super.key});

  @override
  State<AwsBackupPage> createState() => _AwsBackupPageState();
}

class _AwsBackupPageState extends State<AwsBackupPage> {
  final FlutterTts _tts = FlutterTts();
  final AwsBackupService _backupService = AwsBackupService();
  final CognitoAuthService _authService = CognitoAuthService();
  final BackupEncryptionService _encryptionService = BackupEncryptionService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  final Set<int> _selectedIndexes = <int>{};

  List<DiaryBackupEntry> _entries = const [];
  bool _loading = true;
  bool _backingUp = false;
  bool _hideAccountPassword = true;
  bool _hidePassphrase = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _configureAccessibility();
    _loadLocalEntries();
  }

  Future<void> _configureAccessibility() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
  }

  // Version 2.0 cybersecurity change: legacy recordings remain the source
  // of truth. This screen reads them but never edits or deletes local entries.
  Future<void> _loadLocalEntries() async {
    final preferences = await SharedPreferences.getInstance();
    final storedEntries = preferences.getStringList('recordings') ?? const [];
    final entries = <DiaryBackupEntry>[];

    for (final storedEntry in storedEntries) {
      final parsed = DiaryBackupEntry.fromLegacyRecord(storedEntry);
      if (parsed != null && await File(parsed.filePath).exists()) {
        entries.add(parsed);
      }
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });

    final message = entries.isEmpty
        ? 'No saved diary recordings are available to back up.'
        : 'Secure cloud backup. Select diary recordings, enter a private passphrase, and confirm before uploading.';
    await _tts.speak(message);
  }

  Future<void> _startBackup() async {
    if (_selectedIndexes.isEmpty) {
      await _setStatus('Select at least one diary recording.', isError: true);
      return;
    }
    if (_passphraseController.text.length < 12) {
      await _setStatus(
        'Use a private backup passphrase with at least 12 characters.',
        isError: true,
      );
      return;
    }
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      await _setStatus(
        'Enter your secure backup account username and password.',
        isError: true,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm secure cloud backup'),
            content: Text(
              'Encrypt and upload ${_selectedIndexes.length} selected '
              'recording${_selectedIndexes.length == 1 ? '' : 's'}? '
              'The backup is optional. Local recordings will remain on this device. '
              'You must remember the passphrase to decrypt the backup later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Encrypt and back up'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;
    setState(() {
      _backingUp = true;
      _statusMessage = 'Authenticating the secure backup request...';
    });
    await _tts.speak('Authenticating the secure backup request.');

    try {
      // Version 2.0 cybersecurity change: Cognito returns a short-lived token
      // used only for this request. Credentials and tokens are never persisted.
      final idToken = await _authService.authenticate(
        username: _usernameController.text,
        password: _passwordController.text,
      );
      _passwordController.clear();
      if (!mounted) return;
      setState(
          () => _statusMessage = 'Encrypting selected diary recordings...');
      await _tts.speak('Authentication complete. Encrypting the recordings.');

      final selectedEntries =
          _selectedIndexes.map((index) => _entries[index]).toList();
      final encryptedBytes = await _encryptionService.encryptEntries(
        entries: selectedEntries,
        passphrase: _passphraseController.text,
      );
      if (!mounted) return;
      setState(() => _statusMessage = 'Uploading encrypted backup securely...');
      await _tts.speak('Encryption complete. Starting the secure upload.');

      final timestamp = DateTime.now().toUtc();
      final compactTimestamp = '${timestamp.year.toString().padLeft(4, '0')}'
          '${timestamp.month.toString().padLeft(2, '0')}'
          '${timestamp.day.toString().padLeft(2, '0')}T'
          '${timestamp.hour.toString().padLeft(2, '0')}'
          '${timestamp.minute.toString().padLeft(2, '0')}'
          '${timestamp.second.toString().padLeft(2, '0')}Z';
      final result = await _backupService.uploadEncryptedBackup(
        encryptedBytes: encryptedBytes,
        idToken: idToken,
        fileName: 'diary-world-backup-$compactTimestamp.diarybackup.json',
      );
      _passphraseController.clear();
      await _setStatus(
        'Backup completed successfully. Reference: ${result.backupId}',
        isError: false,
      );
    } on BackupEncryptionException catch (error) {
      await _setStatus(error.message, isError: true);
    } on CognitoAuthException catch (error) {
      _passwordController.clear();
      await _setStatus(error.message, isError: true);
    } on AwsBackupException catch (error) {
      await _setStatus(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _setStatus(String message, {required bool isError}) async {
    if (!mounted) return;
    setState(() => _statusMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
      ),
    );
    await _tts.speak(message);
  }

  @override
  void dispose() {
    _backupService.close();
    _authService.close();
    _usernameController.dispose();
    _passwordController.dispose();
    _passphraseController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Cloud Backup'),
        backgroundColor: const Color(0xFF00494D),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      'Version 2.0 optional AWS backup',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your diary stays local and works offline. Nothing is uploaded '
                    'until you select recordings and confirm. Selected recordings '
                    'are encrypted on this device before upload.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (_backupService.configuredEndpoint == null ||
                      !_authService.isConfigured)
                    Card(
                      color: Colors.amber.shade100,
                      child: const ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Secure backup is not configured'),
                        subtitle: Text(
                          'Build with the HTTPS API endpoint, Cognito region, and Cognito client ID.',
                        ),
                      ),
                    ),
                  if (_entries.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('No recordings available'),
                        subtitle:
                            Text('Create and save a recording locally first.'),
                      ),
                    )
                  else ...[
                    Semantics(
                      header: true,
                      child: const Text(
                        'Choose recordings',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...List.generate(_entries.length, (index) {
                      final entry = _entries[index];
                      return CheckboxListTile(
                        value: _selectedIndexes.contains(index),
                        title: Text(entry.name),
                        subtitle: Text('${entry.date} at ${entry.time}'),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: _backingUp
                            ? null
                            : (selected) {
                                setState(() {
                                  if (selected ?? false) {
                                    _selectedIndexes.add(index);
                                  } else {
                                    _selectedIndexes.remove(index);
                                  }
                                });
                              },
                      );
                    }),
                    const SizedBox(height: 16),
                    // Version 2.0 cybersecurity change: authentication fields
                    // are transient and intentionally have no persistence.
                    TextField(
                      controller: _usernameController,
                      enabled: !_backingUp,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Backup account username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      enabled: !_backingUp,
                      obscureText: _hideAccountPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Backup account password',
                        helperText:
                            'Used only to request a short-lived Cognito token.',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hideAccountPassword
                              ? 'Show account password'
                              : 'Hide account password',
                          onPressed: () => setState(
                            () => _hideAccountPassword = !_hideAccountPassword,
                          ),
                          icon: Icon(
                            _hideAccountPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passphraseController,
                      enabled: !_backingUp,
                      obscureText: _hidePassphrase,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'Private backup passphrase',
                        helperText:
                            'At least 12 characters; never sent to AWS.',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _hidePassphrase
                              ? 'Show passphrase'
                              : 'Hide passphrase',
                          onPressed: () => setState(
                            () => _hidePassphrase = !_hidePassphrase,
                          ),
                          icon: Icon(
                            _hidePassphrase
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      button: true,
                      label: 'Confirm and securely back up selected recordings',
                      child: FilledButton.icon(
                        onPressed: _backingUp ||
                                _backupService.configuredEndpoint == null ||
                                !_authService.isConfigured
                            ? null
                            : _startBackup,
                        icon: _backingUp
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.lock),
                        label: Text(
                          _backingUp
                              ? 'Backing up...'
                              : 'Confirm secure backup',
                        ),
                      ),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
