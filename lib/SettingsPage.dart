import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:diaryworld/AccessibilitySettingsPage.dart';
import 'package:diaryworld/DeviceConnectivityPage.dart';
import 'package:diaryworld/guidepage.dart';
import 'package:diaryworld/aws_backup/aws_backup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _hasSpoken = false; // Flag to ensure TTS only happens once

  @override
  void initState() {
    super.initState();
    _flutterTts.setLanguage("en-US");
  }

  // Function to read the settings page aloud
  void _readSettings() async {
    // Read out the main sections and their titles
    await _flutterTts.speak('Settings');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out the profile section
    await _flutterTts.speak('Profile');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out the profile fields
    await _flutterTts.speak('First Name, Katumba');
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak('Last Name, Kane');
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak('Email, Kkatumba@gmail.com');
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak('Password or Pin, ********');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out the languages section
    await _flutterTts.speak('Languages');
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak('Primary Language');
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts.speak('Other Languages');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out reminders & notifications
    await _flutterTts.speak('Reminders and Notifications');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out accessibility
    await _flutterTts.speak('Accessibility');
    await _flutterTts.awaitSpeakCompletion(true);

    // Version 2.0 AWS secure-backup change: announce the optional backup entry
    // so voice-first users know it is available from Settings.
    await _flutterTts.speak('Secure Cloud Backup');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out Help section
    await _flutterTts.speak('Help');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out device connectivity
    await _flutterTts.speak('Device Connectivity');
    await _flutterTts.awaitSpeakCompletion(true);

    // Read out the note section
    await _flutterTts.speak('Note: Say the option to choose it');
    await _flutterTts.awaitSpeakCompletion(true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSpoken) {
      _readSettings();
      _hasSpoken = true; // Make sure it only speaks once
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF00494D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        color: const Color(0xFF00494D),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Profile Section
                const Text(
                  'PROFILE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                _buildProfileTile('First Name', 'Katumba'),
                _buildProfileTile('Last Name', 'Kane'),
                _buildProfileTile('Email', 'Kkatumba@gmail.com'),
                _buildProfileTile('Password or Pin', '********'),
                const Divider(color: Colors.grey),

                // Languages Section
                const SizedBox(height: 16),
                const Text(
                  'Languages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTile('Primary Language', Icons.language, () {}),
                _buildTile('Other Languages', Icons.translate, () {}),
                const Divider(color: Colors.grey),

                // Notifications and Accessibility Section
                _buildTile(
                    'Reminders & Notifications', Icons.notifications, () {}),
                _buildTile('Accessibility', Icons.accessibility, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccessibilitySettingsPage(),
                    ),
                  );
                }),
                // Version 2.0 AWS secure-backup change: cloud backup remains
                // optional and is opened only when the user chooses it.
                _buildTile('Secure Cloud Backup', Icons.cloud_upload, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AwsBackupPage(),
                    ),
                  );
                }),
                const Divider(color: Colors.grey),

                // Help Section
                _buildTile('FAQ / How to Use APP', Icons.help, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GuidePage(),
                    ),
                  );
                }),
                _buildTile('Send Feedback', Icons.feedback, () {}),
                _buildTile('Terms & Privacy Policy', Icons.privacy_tip, () {}),
                const Divider(color: Colors.grey),

                // Device Connectivity
                _buildTile('Device Connectivity', Icons.bluetooth, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceConnectivityPage(),
                    ),
                  );
                }),
                const Center(
                  child: Text(
                    'Designed by Kevin Mukiibi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontStyle: FontStyle.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Logout Button
                const SizedBox(height: 30),

                // Note Section
                const Center(
                  child: Text(
                    'Note: Say the option to choose it',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTile(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00494D).withOpacity(0.7),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
        ],
      ),
    );
  }

  Widget _buildTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing:
          const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
      onTap: onTap,
    );
  }
}
