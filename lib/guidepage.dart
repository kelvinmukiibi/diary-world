import 'package:flutter/material.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key});

  @override
  GuidePageState createState() => GuidePageState();
}

class GuidePageState extends State<GuidePage> {
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Section
            const Text(
              "How-To-Use APP",
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            // Description
            Card(
              elevation: 3,
              color: Colors.grey[200],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Welcome to Visual And Hands-Free Diary App! This app is designed to empower you with hands-free and eyes-free capabilities. Use your voice to navigate, record diaries, connect devices, and more.",
                  style: TextStyle(fontSize: 16.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Key Commands Section
            const Text(
              "Key Commands",
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            CommandCard("Getting Started",
                "Say 'Help' anytime to hear available commands."),
            CommandCard("Navigation Commands",
                "Say 'Go to Settings,' 'Open Diary,' or 'Connect Device.'"),
            CommandCard("Recording Entries",
                "Say 'New Diary Entry' to start recording your thoughts."),
            CommandCard("Connecting Gadgets",
                "Say 'Pair a device' to link your Bluetooth gadgets."),
            const SizedBox(height: 20),
            // Accessibility Tips Section
            const Text(
              "Accessibility Tips",
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 3,
              color: Colors.grey[200],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("For the best experience:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text("• Speak clearly and naturally."),
                    Text("• Use specific keywords for commands."),
                    Text(
                        "• Adjust voice sensitivity in Accessibility Settings."),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Troubleshooting Section
            Card(
              elevation: 3,
              color: Colors.grey[200],
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Having trouble? Say 'Support' to get help or contact us through the app.",
                  style: TextStyle(fontSize: 16.0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Buttons Section
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            //   children: [
            //     ElevatedButton.icon(
            //       onPressed: () {
            //         // Navigate to Full Manual Page
            //       },
            //       icon: Icon(Icons.book),
            //       label: Text("View Full Manual"),
            //       style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            //     ),
            //     ElevatedButton.icon(
            //       onPressed: () {
            //         // Navigate to Support Page
            //       },
            //       icon: Icon(Icons.help),
            //       label: Text("Contact Support"),
            //       style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            //     ),
            //   ],
            // ),
          ],
        ),
      ),
    );
  }

  // Widget for Commands
  Widget CommandCard(String title, String description) {
    return Card(
      elevation: 3,
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
      ),
    );
  }
}
