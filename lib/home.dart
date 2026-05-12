import 'package:diaryworld/AudioRecorderPage.dart';
import 'package:diaryworld/RecordingsPage.dart';
import 'package:diaryworld/SettingsPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class DiaryWorldPage extends StatefulWidget {
  const DiaryWorldPage({super.key});

  @override
  _DiaryWorldPageState createState() => _DiaryWorldPageState();
}

class _DiaryWorldPageState extends State<DiaryWorldPage> {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _speechText = "";

  bool speak = false;

  @override
  void initState() {
    super.initState();
    _readPageContent(); // Start reading content first
  }

  // Function to read out the initial page content
  Future<void> _readPageContent() async {
    setState(() {
      speak = false;
    });

    // Set the onCompletion callback to trigger after speech is completed
    _flutterTts.setCompletionHandler(() {
      print("Speech completed");
    });

    // Speak the first text
    await _flutterTts
        .speak('Welcome to our Diary World. Let your ears be your eyes ');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(seconds: 2));
    await _flutterTts.speak(' and your mouth be your hands.');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(seconds: 2));
    // Speak the second text
    await _flutterTts.speak('Press start to begin a new recording,');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(seconds: 2));
    await _flutterTts.speak('press records to view saved recordings,');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(seconds: 2));
    await _flutterTts.speak('or press settings to change your Preferences.');
    await Future.delayed(const Duration(seconds: 2));
    await _flutterTts.awaitSpeakCompletion(true);
    await _flutterTts
        .speak('You can press buttons or say the command to navigate.');
    speak = false;
    await _flutterTts.awaitSpeakCompletion(true);
    // After the content has been read, start listening (if needed)
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      speak = true;
    });

    // After the content has been read, start listening if the flag is true
    if (speak) {
      _startListening();
    }
  }

  // Function to perform actions based on the command
  Future<void> _performAction(String action) async {
    await _flutterTts.speak('You said $action. Navigating...');
    if (action.toLowerCase() == "start") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AudioRecorderPage()),
      );
    } else if (action.toLowerCase() == "records") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => RecordingsPage()),
      );
    } else if (action.toLowerCase() == "settings") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SettingsPage()),
      );
    } else {
      await _flutterTts.speak('Command not recognized. Please try again.');
      _startListening();
    }
  }

  // Function to start listening to commands
  void _startListening() async {
    bool available = await _speechToText.initialize();
    if (available) {
      setState(() {
        _isListening = true;
      });
      _speechToText.listen(onResult: (result) {
        setState(() {
          _speechText = result.recognizedWords;
        });
        // Process the command when speech is recognized
        _performAction(_speechText);
      });
    } else {
      await _flutterTts
          .speak('Speech recognition is not available. Please try again.');
    }
  }

  // Function to stop listening (if needed)
  void _stopListening() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00665F), // Background color
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title Text
              const Text(
                'WELCOME TO OUR DIARY WORLD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // Subtitle Text
              const Text(
                'Let Your Ears Be Your Eyes.\nAnd Your Mouth Be Your Hands.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),
              // Icon Circle
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: Color(0xFF003D39), // Dark circle background
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.hearing, // Ear icon
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Buttons to simulate commands
              _buildButton('START', () => _performAction('Start')),
              const SizedBox(height: 15),
              _buildButton('RECORDS', () => _performAction('Records')),
              const SizedBox(height: 15),
              _buildButton('SETTINGS', () => _performAction('Settings')),
              const SizedBox(height: 30),
              // Footer Text
              const Text(
                '"Press one of the buttons or say a command to navigate."',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 30),
              // Show recognized voice command
              Text(
                'Voice Command: $_speechText',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for buttons to simulate actions
  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF003D39), // Button color
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
