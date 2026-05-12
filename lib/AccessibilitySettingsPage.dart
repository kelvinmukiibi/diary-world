import 'package:flutter/material.dart';

class AccessibilitySettingsPage extends StatefulWidget {
  const AccessibilitySettingsPage({super.key});

  @override
  _AccessibilitySettingsPageState createState() =>
      _AccessibilitySettingsPageState();
}

class _AccessibilitySettingsPageState extends State<AccessibilitySettingsPage> {
  double voiceSensitivity = 50.0;
  double speechFeedback = 50.0;
  bool privacyMode = false;
  bool soundCues = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white, // Title text color
            fontSize: 20, // Optional: adjust font size
            fontWeight: FontWeight.bold, // Optional: adjust font weight
          ),
        ),
        backgroundColor: const Color(0xFF00494D), // AppBar background color
        centerTitle: true, // Center the title
        iconTheme: const IconThemeData(color: Colors.white), // Back icon color
      ),
      body: Container(
        color: const Color(0xFF00494D),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accessibility',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Customize your experience to ensure smooth and effortless interaction. Adjust features designed for hands-free and eyes-free usage.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Colors.grey[800],
              leading: const Icon(Icons.shortcut, color: Colors.white),
              title: const Text(
                'Google Assistant / Siri Shortcuts',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Add speech commands to help voice assistants operate using the App.',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                // Implement navigation to shortcuts configuration
              },
            ),
            const SizedBox(height: 10),
            _buildSlider(
              icon: Icons.mic,
              title: 'Voice Sensitivity',
              value: voiceSensitivity,
              onChanged: (value) {
                setState(() {
                  voiceSensitivity = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildSlider(
              icon: Icons.speaker,
              title: 'Speech Feedback',
              value: speechFeedback,
              onChanged: (value) {
                setState(() {
                  speechFeedback = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildToggleSwitch(
              icon: Icons.privacy_tip,
              title: 'Privacy Mode',
              value: privacyMode,
              onChanged: (value) {
                setState(() {
                  privacyMode = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _buildToggleSwitch(
              icon: Icons.surround_sound,
              title: 'Sound Cues',
              value: soundCues,
              onChanged: (value) {
                setState(() {
                  soundCues = value;
                });
              },
            ),
            const Spacer(),
            const Center(
              child: Text(
                'Note: Say the option to choose it',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required IconData icon,
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white)),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          label: value.toString(),
          activeColor: Colors.green,
          inactiveColor: Colors.white24,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildToggleSwitch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      tileColor: Colors.grey[800],
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Switch(
        value: value,
        activeThumbColor: Colors.green,
        onChanged: onChanged,
      ),
    );
  }
}
