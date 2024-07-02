import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

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
  Duration _remainingTime = Duration(minutes: 1); // Mengubah durasi menjadi 1 menit
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _breakTimer?.cancel();
    Vibration.cancel(); // Pastikan getaran berhenti ketika widget dibuang
    _audioPlayer.dispose(); // Hentikan dan buang audio player
    super.dispose();
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildLogBox(
                        'Break started at',
                        _startBreakTime != null
                            ? '${_startBreakTime!.hour}:${_startBreakTime!.minute.toString().padLeft(2, '0')} on ${_formatDate(_startBreakTime!)}'
                            : 'Not started yet',
                        double.infinity,
                        120,
                        Alignment.center,
                        16,
                        17,
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: _buildLogBox(
                        'Break ended at',
                        _endBreakTime != null
                            ? '${_endBreakTime!.hour}:${_endBreakTime!.minute.toString().padLeft(2, '0')} on ${_formatDate(_endBreakTime!)}'
                            : 'Not ended yet',
                        double.infinity,
                        120,
                        Alignment.center,
                        16,
                        17,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15),
                _buildLogBox(
                  'Break duration',
                  _calculateBreakDuration(),
                  double.infinity,
                  120,
                  Alignment.center,
                  16,
                  20,
                ),
                SizedBox(height: 15),
                Divider(thickness: 1),
                ListTile(
                  title: Text(
                    'Lihat Log Break',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  trailing: Icon(Icons.arrow_forward, size: 24, color: Colors.blue),
                  onTap: () {
                    // Navigasi ke halaman log break
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

  void _startBreak() {
    setState(() {
      _startBreakTime = DateTime.now();
      _isBreakStarted = true;
      _isBreakEndedAutomatically = false;
      _remainingTime = Duration(minutes: 1); // Mengubah durasi menjadi 1 menit
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
    });
  }

  void _endBreak() {
    setState(() {
      _endBreakTime = DateTime.now();
      _isBreakStarted = false;
      _isBreakEndedAutomatically = false;
      _breakTimer?.cancel();
      Vibration.cancel(); // Pastikan getaran berhenti ketika break diakhiri
      _audioPlayer.stop(); // Pastikan suara berhenti ketika break diakhiri
    });
  }

  void _handleBreakEnd() {
    setState(() {
      _isBreakStarted = false;
      _isBreakEndedAutomatically = true;
    });
    // Membuat perangkat bergetar terus menerus
    if (Vibration.hasVibrator() != null) {
      Vibration.vibrate(pattern: [0, 1000, 1000], repeat: 0);
    }
    // Memutar suara secara berulang
    _playSound();
    print("Break time ended. Device should vibrate continuously until stopped.");
  }

  void _playSound() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
  }

  Widget _buildLogBox(String title, String content, double width, double height, Alignment alignment, double textSize, double contentTextSize) {
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
      alignment: alignment,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(fontSize: textSize, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Divider(thickness: 1),
          Text(
            content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: contentTextSize),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
