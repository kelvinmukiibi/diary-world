import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:diaryworld/AudioPlayerPage.dart';
import 'package:diaryworld/AudioRecorderPage.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart'; // For formatting the date and time
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  _RecordingsPageState createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  DateTime _focusedDay = DateTime.now();
  bool _isListening = false;
  DateTime? _selectedDay;
  List<Map<String, String>> _recentRecordings = [];

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _initializeTTS();
    _initializeSpeechToText();
    _readRecordings();
  }

  void _initializeTTS() {
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
  }

  // Initialize Speech-to-Text
  void _initializeSpeechToText() async {
    bool available = await _speech.initialize();
    if (available) {
      _startListening();
    } else {
      print("Speech-to-Text not available");
    }
  }

// Start listening for commands
  void _startListening() async {
    if (!_isListening) {
      setState(() {
        _isListening = true;
      });

      _speech.listen(onResult: (result) {
        print(result.recognizedWords);
        if (result.recognizedWords.toLowerCase().contains("play")) {
          String audioName = result.recognizedWords.split("play")[1].trim();
          _playAudioByName(audioName);
        } else if (result.recognizedWords.toLowerCase().contains("record")) {
          _startRecording();
        } else if (result.recognizedWords.toLowerCase().contains("search")) {
          _showSearchDialog(context);
        }
      });
    }
  }

  // Stop listening for commands
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  // Play audio by name
  void _playAudioByName(String audioName) {
    var recording = _recentRecordings.firstWhere(
        (rec) => rec['name']?.toLowerCase() == audioName.toLowerCase(),
        orElse: () => {});
    if (recording.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerPage(
            filePath: recording['filePath']!,
            title: recording['name']!,
            date: recording['date']!,
            time: recording['time']!,
          ),
        ),
      );
    } else {
      _flutterTts.speak("Sorry, I couldn't find the audio for $audioName.");
    }
  }

  // Start recording
  void _startRecording() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AudioRecorderPage(),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  // Load saved recordings from SharedPreferences
  Future<void> _loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? recordings = prefs.getStringList('recordings');

    if (recordings != null) {
      setState(() {
        _recentRecordings = recordings.map((recording) {
          // Split the string into individual components
          var parts = recording.split('|');
          return {
            'name': parts[0],
            'date': parts[1],
            'time': parts[2],
            'filePath': parts[3],
          };
        }).toList();
      });
    }
  }

  Future<void> _readRecordings() async {
    await _flutterTts.speak("Here are your available recordings:");
    await _flutterTts.awaitSpeakCompletion(true);
    for (var recording in _recentRecordings) {
      String name = recording["name"]!;
      String date = recording["date"]!;
      String time = recording["time"]!;
      await _flutterTts.speak("Recording $name from $date at $time.");
      await _flutterTts.awaitSpeakCompletion(true);
    }
    // After reading, ask the user to give a voice command to play a recording
    await _flutterTts
        .speak("Please say the name of the recording you want to play.");
    await _flutterTts.awaitSpeakCompletion(true);
    _startListening();
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF00494D),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Voice-Based Record Search",
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: TextField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      hintText: "Search by keyword...",
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.grey),
                    ),
                    onChanged: (query) {
                      // Handle search logic here
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Results:",
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Ensure that _recentRecordings is never null
                if (_recentRecordings.isNotEmpty)
                  ..._recentRecordings.map((recording) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        recording["name"] ?? 'Unknown', // Add a fallback value
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "${recording["date"] ?? 'Unknown'} • ${recording["time"] ?? 'Unknown'}",
                        style: TextStyle(color: Colors.grey[300]),
                      ),
                      trailing: Icon(Icons.mic, color: Colors.grey[300]),
                      onTap: () {
                        Navigator.pop(context); // Close the dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerPage(
                              filePath: recording['filePath']!,
                              title: recording['name']!,
                              date: recording['date']!,
                              time: recording['time']!,
                            ),
                          ),
                        );
                      },
                    );
                  })
                else
                  const Center(
                    child: Text(
                      "No recordings found.",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  "Note: Speak the Keyword to Search",
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[300],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Speak the instructions on load
    if (_recentRecordings.isNotEmpty) {
      _flutterTts.speak(
          "Welcome to the recordings page. You can say 'Play audio [name]', 'Search records', or 'Record' to start.");
    } else {
      _flutterTts.speak(
          "Welcome to the recordings page. You can say 'Search records', or 'Record' to start.");
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "RECORDINGS",
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF00494D),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Calendar Section
              Container(
                color: const Color(0xFF00494D),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    const Text(
                      "Calendar",
                      style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Colors.tealAccent,
                          shape: BoxShape.circle,
                        ),
                        weekendTextStyle: TextStyle(color: Colors.red),
                      ),
                      headerStyle: const HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        titleTextStyle:
                            TextStyle(color: Colors.white, fontSize: 16.0),
                        leftChevronIcon:
                            Icon(Icons.chevron_left, color: Colors.white),
                        rightChevronIcon:
                            Icon(Icons.chevron_right, color: Colors.white),
                      ),
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) {
                          return Center(
                            child: Text(
                              '${day.day}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Recent Recordings Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recent Recordings",
                      style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00494D)),
                    ),
                    const SizedBox(height: 10),
                    // Display the recordings
                    if (_recentRecordings.isEmpty)
                      const Center(child: Text("No recordings found"))
                    else
                      ..._recentRecordings.map((recording) {
                        return Card(
                          elevation: 2,
                          child: ListTile(
                            title: Text(recording['name']!),
                            subtitle: Text(
                                "${recording['date']} • ${recording['time']}"),
                            trailing: IconButton(
                              icon: const Icon(Icons.mic,
                                  color: Color(0xFF00494D)),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AudioPlayerPage(
                                      filePath: recording['filePath']!,
                                      title: recording['name']!,
                                      date: recording['date']!,
                                      time: recording['time']!,
                                    ),
                                  ),
                                );

                                print(recording['filePath']!);
                              },
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioRecorderPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.mic),
                      label: const Text("Record"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00494D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showSearchDialog(context),
                      icon: const Icon(Icons.search),
                      label: const Text("Search Record"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00494D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF00494D),
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.support), label: "AI Support"),
          BottomNavigationBarItem(
              icon: Icon(Icons.group), label: "Blind Community"),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: "Settings"),
        ],
        onTap: (index) {
          // Handle bottom navigation actions
        },
      ),
    );
  }
}
