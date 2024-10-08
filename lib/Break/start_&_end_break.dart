import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/src/source.dart';

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
  Timer? _vibrationTimer;
  Timer? _audioTimer;
  Duration _breakDuration = Duration(hours: 1);
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
    _vibrationTimer?.cancel();
    _audioTimer?.cancel();
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
    DocumentSnapshot settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('break_times').get();
    if (settingsDoc.exists) {
      setState(() {
        _adminStartBreakTime = (settingsDoc['adminStartBreakTime'] as Timestamp).toDate();
        _adminEndBreakTime = (settingsDoc['adminEndBreakTime'] as Timestamp).toDate();
      });
    }
  }

  Future<void> _saveAdminBreakTimesToFirestore() async {
    await FirebaseFirestore.instance.collection('settings').doc('break_times').set({
      'adminStartBreakTime': _adminStartBreakTime,
      'adminEndBreakTime': _adminEndBreakTime,
    });
    _loadAdminBreakTimes();
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

    if (now.isBefore(_adminStartBreakTime!) || now.isAfter(_adminEndBreakTime!)) {
      _showInvalidTimeDialog();
      return;
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
      _vibrationTimer?.cancel();
      _audioTimer?.cancel();
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
        if (now.isBefore(_endBreakTime!)) {
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

    _startVibrationAndAlarm();

    if (_currentBreakDocRef != null) {
      await _currentBreakDocRef!.update({
        'end_break': _endBreakTime,
        'break_duration': _calculateBreakDuration(),
      });
    }

    _saveBreakStatus();
  }

  void _startVibrationAndAlarm() {
    _vibrationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _vibratePhone();
    });

    _audioTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _playAlarm();
    });
  }

  void _playAlarm() async {
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));  // Gunakan AssetSource untuk file lokal
  }

  void _vibratePhone() {
    Vibration.vibrate();
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
      initialTime: TimeOfDay.fromDateTime(isStart ? _adminStartBreakTime ?? DateTime.now() : _adminEndBreakTime ?? DateTime.now()),
    );

    if (timeOfDay != null) {
      setState(() {
        final now = DateTime.now();
        if (isStart) {
          _adminStartBreakTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
        } else {
          _adminEndBreakTime = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
        }
        _saveAdminBreakTimesToFirestore();
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
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade700, width: 1.0),
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
                color: Colors.teal.shade900,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, bottom: 0.0),
            child: Divider(thickness: 1, color: Colors.teal.shade700),
          ),
          Expanded(
            child: Center(
              child: Text(
                content,
                style: TextStyle(
                  fontSize: contentTextSize,
                  color: Colors.teal.shade700,
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('break_times').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.data() != null) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            _adminStartBreakTime = (data['adminStartBreakTime'] as Timestamp).toDate();
            _adminEndBreakTime = (data['adminEndBreakTime'] as Timestamp).toDate();
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Break Start/End'),
            centerTitle: true,
            backgroundColor: Colors.teal.shade700,
            actions: _isAdmin
                ? [
              IconButton(
                icon: Icon(Icons.settings, color: Colors.white),
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
                            'Break Time Set:',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                          ),
                          Text(
                            'Start: ${_formatTime(_adminStartBreakTime!)}',
                            style: TextStyle(fontSize: 16, color: Colors.teal.shade700),
                          ),
                          Text(
                            'End: ${_formatTime(_adminEndBreakTime!)}',
                            style: TextStyle(fontSize: 16, color: Colors.teal.shade700),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    Text(
                      'Break Status: ${_isBreakStarted ? 'Started' : 'Not Started'}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                    ),
                    SizedBox(height: 20),
                    if (_isBreakStarted)
                      Text(
                        'Remaining Time: ${_remainingTime.inMinutes.toString().padLeft(2, '0')}:${_remainingTime.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                      ),
                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: (!_isBreakStarted && !_isBreakEndedAutomatically) ? _startBreak : null,
                          child: Text('Start Break', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                            textStyle: TextStyle(fontSize: 16),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: (_isBreakStarted || _isBreakEndedAutomatically) ? _endBreak : null,
                          child: Text('End Break', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                            textStyle: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    Divider(thickness: 2, color: Colors.teal.shade700),
                    SizedBox(height: 5),
                    SizedBox(height: 15),
                    Divider(thickness: 2, color: Colors.teal.shade700),
                    ListTile(
                      title: Text(
                        'Lihat Log Break',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700
                        ),
                      ),
                      trailing: Icon(
                          Icons.arrow_forward,
                          size: 24,
                          color: Colors.teal.shade700
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BreakHistoryPage()),
                        );
                      },
                    ),
                    Divider(thickness: 2, color: Colors.teal.shade700),
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
                        child: Text('Set Start Time', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                          textStyle: TextStyle(fontSize: 16),
                        ),
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
                        child: Text('Set End Time', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                          textStyle: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAdminSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('Set Start Break Time', style: TextStyle(color: Colors.teal.shade900)),
                  trailing: Icon(Icons.access_time, color: Colors.teal.shade700),
                  onTap: () {
                    _pickTime(context, true);
                  },
                ),
                ListTile(
                  title: Text('Set End Break Time', style: TextStyle(color: Colors.teal.shade900)),
                  trailing: Icon(Icons.access_time, color: Colors.teal.shade700),
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
