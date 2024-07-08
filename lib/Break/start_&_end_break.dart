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
  DateTime? _adminStartBreakTime;
  DateTime? _adminEndBreakTime;
  bool _isBreakStarted = false;
  bool _isBreakEndedAutomatically = false;
  bool _isAdmin = false;
  Timer? _breakTimer;
  Duration _breakDuration = Duration(hours: 1); // Durasi break menjadi 1 jam
  Duration _remainingTime = Duration(hours: 1);
  final AudioPlayer _audioPlayer = AudioPlayer();
  DocumentReference? _currentBreakDocRef;

  @override
  void initState() {
    super.initState();
    _loadBreakStatus();
    _loadAdminBreakTimes();
    _checkIfAdmin();
  }

  @override
  void dispose() {
    _breakTimer?.cancel();
    Vibration.cancel();
    _audioPlayer.dispose();
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

  Future<void> _loadAdminBreakTimes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminStartBreakTime = DateTime.tryParse(prefs.getString('adminStartBreakTime') ?? '');
      _adminEndBreakTime = DateTime.tryParse(prefs.getString('adminEndBreakTime') ?? '');
    });
  }

  Future<void> _saveAdminBreakTimes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adminStartBreakTime', _adminStartBreakTime?.toIso8601String() ?? '');
    await prefs.setString('adminEndBreakTime', _adminEndBreakTime?.toIso8601String() ?? '');
  }

  Future<void> _checkIfAdmin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = userDoc['role'] == 'admin';
      });
    }
  }

  void _startBreak([DateTime? startTime]) async {
    final now = DateTime.now();

    if (_adminStartBreakTime != null && _adminEndBreakTime != null) {
      if (now.isBefore(_adminStartBreakTime!) || now.isAfter(_adminEndBreakTime!)) {
        _showInvalidTimeDialog();
        return;
      }
    }

    setState(() {
      _startBreakTime = startTime ?? now;
      _isBreakStarted = true;
      _isBreakEndedAutomatically = false;
      _endBreakTime = _adminEndBreakTime ?? _startBreakTime!.add(_breakDuration);
      _remainingTime = _endBreakTime!.difference(DateTime.now());
      _startBreakTimer();
    });

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
        'display_name': displayName,
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
        final now = DateTime.now();
        if (_endBreakTime != null && now.isBefore(_endBreakTime!)) {
          _remainingTime = _endBreakTime!.difference(now);
          if (_remainingTime.isNegative) {
            _handleBreakEnd();
            timer.cancel();
          }
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final TimeOfDay? timeOfDay = await showTimePicker(
      context: context,
      initialTime: isStart ? TimeOfDay.fromDateTime(_adminStartBreakTime ?? DateTime.now()) : TimeOfDay.fromDateTime(_adminEndBreakTime ?? DateTime.now()),
    );

    if (timeOfDay != null) {
      setState(() {
        final now = DateTime.now();
        if (isStart) {
          _adminStartBreakTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
        } else {
          _adminEndBreakTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
        }
        _saveAdminBreakTimes();
      });
    }
  }

  void _showInvalidTimeDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Invalid Break Time'),
          content: Text('Break can only be started within the time set.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
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
        actions: _isAdmin
            ? [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              _showAdminSettingsDialog(context);
            },
          ),
        ]
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                if (_adminStartBreakTime != null && _adminEndBreakTime != null)
                  Column(
                    children: [
                      Text(
                        'Break Time Set :',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Start: ${_formatTime(_adminStartBreakTime!)}',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        'End: ${_formatTime(_adminEndBreakTime!)}',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
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
                if (_isAdmin) ...[
                  SizedBox(height: 20),
                  _buildLogBox(
                    'Admin Start Break Time',
                    _adminStartBreakTime != null ? _formatTime(_adminStartBreakTime!) : 'Not Set',
                    300,
                    60,
                    18,
                    18,
                  ),
                  ElevatedButton(
                    onPressed: () => _pickTime(context, true),
                    child: Text('Set Start Time'),
                  ),
                  SizedBox(height: 15),
                  _buildLogBox(
                    'Admin End Break Time',
                    _adminEndBreakTime != null ? _formatTime(_adminEndBreakTime!) : 'Not Set',
                    300,
                    60,
                    18,
                    18,
                  ),
                  ElevatedButton(
                    onPressed: () => _pickTime(context, false),
                    child: Text('Set End Time'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAdminSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Set Start Break Time'),
                  trailing: Icon(Icons.access_time),
                  onTap: () {
                    _pickTime(context, true);
                  },
                ),
                ListTile(
                  title: Text('Set End Break Time'),
                  trailing: Icon(Icons.access_time),
                  onTap: () {
                    _pickTime(context, false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
