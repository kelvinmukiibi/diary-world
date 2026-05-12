import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Flutter TTS for speaking
import 'package:speech_to_text/speech_to_text.dart'; // Speech to Text for listening

class AudioRecorderPage extends StatefulWidget {
  const AudioRecorderPage({super.key});

  @override
  _AudioRecorderPageState createState() => _AudioRecorderPageState();
}

class _AudioRecorderPageState extends State<AudioRecorderPage> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String _filePath = '';
  final TextEditingController _nameController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts(); // Text-to-Speech instance
  final SpeechToText _speech = SpeechToText(); // Speech-to-Text instance
  bool _isListening = false; // Listening status flag

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _initializeSpeechToText();
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
  }

  Future<void> _initializeSpeechToText() async {
    bool available = await _speech.initialize();
    if (available) {
      _speakInstructions();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Speech recognition is not available."),
      ));
    }
  }

  Future<void> _speakInstructions() async {
    await _flutterTts.speak('Welcome to the Audio Recorder.');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(
        seconds: 1)); // Delay for a smoother transition between instructions
    await _flutterTts.speak(
        'You can say "Start" to begin recording, "Pause" to pause the recording, or "Save" to stop and save it.');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(seconds: 1));
    await _flutterTts.speak(
        'You can also press the buttons on the screen to control the recording.');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(seconds: 1));
    await _flutterTts.speak('Ready to begin recording.');
    await _flutterTts.awaitSpeakCompletion(true);
    await Future.delayed(const Duration(seconds: 1));
    _startListening();
  }

  // Function to start speech listening
  void _startListening() {
    setState(() {
      _isListening = true;
    });
    _speech.listen(onResult: (result) {
      if (result.hasConfidenceRating && result.confidence > 0.5) {
        _performAction(result.recognizedWords);
      }
    });
  }

  // Function to stop listening for commands
  void _stopListening() {
    setState(() {
      _isListening = false;
    });
    _speech.stop();
  }

// Method to handle speech input for the name and save button
  Future<void> _listenForName() async {
    // Start listening to the user's voice for the name
    _speech.listen(onResult: (result) {
      if (result.hasConfidenceRating && result.confidence > 0.5) {
        // Set the recognized words into the text field
        setState(() {
          _nameController.text = result.recognizedWords;
        });
      }
    });
  }

// Method to start listening for the "Save" command
  Future<void> _listenForSaveCommand() async {
    _speech.listen(onResult: (result) {
      if (result.hasConfidenceRating && result.confidence > 0.5) {
        String command = result.recognizedWords.toLowerCase();
        if (command.contains("save")) {
          _saveRecording(_nameController.text);
          _speak("Recording saved as ${_nameController.text}");
          Navigator.pop(context); // Close the save dialog
          _startListening();
        }
      }
    });
  }

  // Function to perform actions based on the recognized command
  void _performAction(String command) async {
    if (command.toLowerCase() == 'start') {
      if (!_isRecording) {
        await _startRecording();
      }
    } else if (command.toLowerCase() == 'pause') {
      if (_isRecording) {
        await _stopRecording();
      }
    } else if (command.toLowerCase() == 'save') {
      if (!_isRecording) {
        _showSaveDialog();
      }
    } else if (command.toLowerCase() == 'stop') {
      if (_isRecording) {
        await _stopRecording();
      }
    } else if (command.toLowerCase() == 'back') {
      if (!_isRecording) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _startRecording() async {
    Directory tempDir = await getTemporaryDirectory();
    String path =
        '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';
    setState(() {
      _filePath = path;
    });

    await _recorder.startRecorder(toFile: path);
    setState(() {
      _isRecording = true;
    });
    _speak("Recording started.");
  }

  Future<void> _stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });
    _speak("Recording stopped.");
    _showSaveDialog(); // Show the dialog to save the recording
  }

  void _showSaveDialog() {
    _listenForName();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Save Recording"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // TextField to display the name
                TextField(
                  controller: _nameController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: "Enter recording name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                // Start listening for the name (if not already doing so)
                ElevatedButton(
                  onPressed: _listenForName,
                  child: const Text("Say Recording Name"),
                ),
              ],
            ),
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),
            // Save button
            TextButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  _saveRecording(_nameController.text);
                  _speak("Recording saved as ${_nameController.text}");
                  Navigator.pop(context);
                  _startListening();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a name")),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    // After opening the dialog, start listening for the save command
    _listenForSaveCommand();
  }

  Future<void> _saveRecording(String name) async {
    try {
      String currentDate = DateFormat('d MMMM yyyy').format(DateTime.now());
      String currentTime = DateFormat('h:mm a').format(DateTime.now());

      Directory appDir = await getApplicationDocumentsDirectory();
      String newPath = '${appDir.path}/$name.aac';

      File recordingFile = File(_filePath);
      if (recordingFile.existsSync()) {
        await recordingFile.rename(newPath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Recording file not found!")),
        );
        return;
      }

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> recordings = prefs.getStringList('recordings') ?? [];

      String newRecording = '$name|$currentDate|$currentTime|$newPath';
      recordings.add(newRecording);
      await prefs.setStringList('recordings', recordings);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recording saved as $name")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save recording: $e")),
      );
    }
  }

  Future<void> _speak(String message) async {
    await _flutterTts.speak(message);
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _nameController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    String currentDate = DateFormat('d MMMM yyyy').format(DateTime.now());
    String currentTime = DateFormat('h:mm a').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF00494D),
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: screenHeight * 0.1,
            ),
            Text(
              "DATE: $currentDate",
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "AUDIO RECORDING - $currentTime",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 30),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.mic,
                size: 50,
                color: Color(0xFF00494D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isRecording ? "LISTENING ....." : "READY TO RECORD",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
            if (_isRecording) ...[
              const Text(
                "Recording in progress...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(
                    _isRecording ? Icons.pause_circle : Icons.play_circle,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.grey,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "SAVE",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Say Pause to Pause or Save to Stop",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
