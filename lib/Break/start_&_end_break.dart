import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'history_break_page.dart';

class BreakStartEndPage extends StatefulWidget {
  const BreakStartEndPage({Key? key}) : super(key: key);

  @override
  _BreakStartEndPageState createState() => _BreakStartEndPageState();
}

class _BreakStartEndPageState extends State<BreakStartEndPage> {
  DateTime? _startBreakTime;
  DateTime? _endBreakTime;
  bool _isBreakStarted = false;
  bool _isBreakEndedAutomatically = false;
  Timer? _breakTimer;
  Duration _breakDuration = Duration(hours: 1); // Durasi break menjadi 1 jam
  Duration _remainingTime = Duration(hours: 1);
  final AudioPlayer _audioPlayer = AudioPlayer();
  DocumentReference? _currentBreakDocRef;
  final TextEditingController _logController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBreakStatus();
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    Vibration.cancel();
    _audioPlayer.dispose();
    _logController.dispose();
    super.dispose();
  }

  Future<void> _loadBreakStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBreakStarted = prefs.getBool('isBreakStarted') ?? false;
      _isBreakEndedAutomatically = prefs.getBool('isBreakEndedAutomatically') ?? false;
      _startBreakTime = DateTime.tryParse(prefs.getString('startBreakTime') ?? '');
      _endBreakTime = DateTime.tryParse(prefs.getString('endBreakTime') ?? '');
    });

    if (_isBreakStarted && _startBreakTime != null) {
      final elapsedTime = DateTime.now().difference(_startBreakTime!);
      _remainingTime = _breakDuration - elapsedTime;
      if (_remainingTime.isNegative) {
        _remainingTime = Duration.zero;
        _handleBreakEnd();
      } else {
        _startBreakTimer();
      }
    }
  }

  Future<void> _saveBreakStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBreakStarted', _isBreakStarted);
    await prefs.setBool('isBreakEndedAutomatically', _isBreakEndedAutomatically);
    await prefs.setString('startBreakTime', _startBreakTime?.toIso8601String() ?? '');
    await prefs.setString('endBreakTime', _endBreakTime?.toIso8601String() ?? '');
    await prefs.setInt('remainingTime', _remainingTime.inSeconds);
  }

  void _startBreak() async {
    setState(() {
      _startBreakTime = DateTime.now();
      _isBreakStarted = true;
      _isBreakEndedAutomatically = false;
      _remainingTime = _breakDuration;
      _startBreakTimer();
    });

    // Simpan waktu mulai break ke Firestore
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String displayName = user.displayName ?? 'Unknown';
      DocumentReference breakDocRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('break_logs')
          .add({
        'start_break': _startBreakTime,
        'end_break': null,
        'break_duration': null,
        'display_name': displayName, // Menyimpan nama pengguna
      });
      _currentBreakDocRef = breakDocRef;
    }

    _saveBreakStatus();
    Workmanager().registerPeriodicTask(
      "1",
      "breakTimer",
      frequency: Duration(minutes: 15),
    );
  }

  void _endBreak() async {
    setState(() {
      _endBreakTime = DateTime.now();
      _isBreakStarted = false;
      _isBreakEndedAutomatically = false;
      _breakTimer?.cancel();
      Vibration.cancel();
      _audioPlayer.stop();
    });

    // Simpan waktu akhir break ke Firestore
    if (_currentBreakDocRef != null) {
      await _currentBreakDocRef!.update({
        'end_break': _endBreakTime,
        'break_duration': _calculateBreakDuration(),
      });
    }

    _saveBreakStatus();
    Workmanager().cancelAll();
  }

  void _startBreakTimer() {
    _breakTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime.inSeconds > 0) {
          _remainingTime = _remainingTime - Duration(seconds: 1);
        } else {
          _handleBreakEnd();
          timer.cancel();
        }
      });
    });
  }

  void _handleBreakEnd() async {
    setState(() {
      _isBreakStarted = false;
      _isBreakEndedAutomatically = true;
      _endBreakTime = DateTime.now();
    });

    // Simpan waktu akhir break ke Firestore ketika break berakhir secara otomatis
    if (_currentBreakDocRef != null) {
      await _currentBreakDocRef!.update({
        'end_break': _endBreakTime,
        'break_duration': _calculateBreakDuration(),
      });
    }

    if (Vibration.hasVibrator() != null) {
      Vibration.vibrate(pattern: [0, 1000, 1000], repeat: 0);
    }
    _playSound();
    _saveBreakStatus();
  }

  void _playSound() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  String _calculateBreakDuration() {
    if (_startBreakTime != null && _endBreakTime != null) {
      Duration breakDuration = _endBreakTime!.difference(_startBreakTime!);
      int minutes = breakDuration.inMinutes;
      int seconds = breakDuration.inSeconds.remainder(60);
      return '${minutes}m ${seconds}s';
    }
    return 'Not calculated';
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  Widget _buildLogBox(String title, String content, double width, double height, double textSize, double contentTextSize) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: textSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 0.0),
            child: Divider(thickness: 1),
          ),
          Expanded(
            child: Center(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: contentTextSize,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Break Start/End'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 20),
                Text(
                  'Break Status: ${_isBreakStarted ? 'Started' : 'Not Started'}',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                if (_isBreakStarted)
                  Text(
                    'Remaining Time: ${_remainingTime.inMinutes.toString().padLeft(2, '0')}:${_remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: (!_isBreakStarted && !_isBreakEndedAutomatically) ? _startBreak : null,
                      child: Text('Start Break'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        textStyle: TextStyle(fontSize: 16),
                        foregroundColor: Colors.black,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: (_isBreakStarted || _isBreakEndedAutomatically) ? _endBreak : null,
                      child: Text('End Break'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                        textStyle: TextStyle(fontSize: 16),
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                Divider(thickness: 2),
                SizedBox(height: 5),
                SizedBox(height: 15),
                Divider(thickness: 1),
                ListTile(
                  title: Text(
                    'Lihat Log Break',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.blue),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BreakHistoryPage()),
                    );
                  },
                ),
                Divider(thickness: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
