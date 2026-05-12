import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class AudioPlayerPage extends StatefulWidget {
  final String filePath;
  final String title;
  final String date;
  final String time;
  // Path to the audio file

  const AudioPlayerPage({
    super.key,
    required this.filePath,
    required this.title,
    required this.date,
    required this.time,
  });

  @override
  _AudioPlayerPageState createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  late AudioPlayer _audioPlayer;
  PlayerState? _playerState;
  Duration? _duration;
  Duration? _position;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;
  bool get _isPaused => _playerState == PlayerState.paused;
  bool get _isStopped => _playerState == PlayerState.stopped;

  String get _durationText => _duration?.toString().split('.').first ?? '';
  String get _positionText => _position?.toString().split('.').first ?? '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initStreams();

    _audioPlayer.setSource(UrlSource(widget.filePath)).then((_) {
      // After the source is set, play the audio
      _play();
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initStreams() {
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _duration = duration;
      });
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _position = position;
      });
    });

    _playerStateChangeSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _playerState = state;
      });
    });
  }

  Future<void> _play() async {
    await _audioPlayer.resume();
    setState(() {
      _playerState = PlayerState.playing;
    });
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
    setState(() {
      _playerState = PlayerState.paused;
    });
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      _playerState = PlayerState.stopped;
      _position = Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00494D),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "DATE: ${widget.date}",
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${widget.title} - ${widget.time}",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 30),
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.volume_up,
                size: 50,
                color: Color(0xFF00494D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isPlaying
                  ? "PLAYING ....."
                  : _isPaused
                      ? "PAUSED"
                      : "STOPPED",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
            Slider(
              onChanged: (value) {
                if (_duration == null) return;
                final position = value * _duration!.inMilliseconds;
                _audioPlayer.seek(Duration(milliseconds: position.round()));
              },
              value: (_position != null && _duration != null)
                  ? (_position!.inMilliseconds / _duration!.inMilliseconds)
                  : 0.0,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _position != null ? _positionText : '00:00',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  _duration != null ? _durationText : '00:00',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _isPlaying || _isPaused ? _stop : null,
                  icon: const Icon(Icons.stop, color: Colors.white, size: 30),
                ),
                IconButton(
                  onPressed: _isPlaying ? _pause : _play,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Say 'Pause' to Pause or 'Stop' to Stop",
                style: TextStyle(color: Colors.teal[700], fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
